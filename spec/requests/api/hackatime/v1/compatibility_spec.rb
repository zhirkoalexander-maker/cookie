require 'swagger_helper'

RSpec.describe 'Api::Hackatime::V1::Compatibility', type: :request do
  def parsed_body(response)
    JSON.parse(response.body)
  end

  def create_heartbeat_span(user, count:, started_at:, step_seconds:, **attrs)
    count.times do |index|
      Heartbeat.create!(
        {
          user: user,
          time: (started_at + (index * step_seconds)).to_f,
          category: 'coding',
          source_type: :direct_entry
        }.merge(attrs)
      )
    end
  end

  path '/api/hackatime/v1/users/{id}/heartbeats' do
    post('Push heartbeats (WakaTime compatible)') do
      tags 'WakaTime Compatibility'
      description 'Endpoint used by WakaTime plugins to send heartbeat data to the server. This is the core endpoint for tracking time.'
      consumes 'application/json'
      security [ Bearer: [], ApiKeyAuth: [] ]

      parameter name: :id, in: :path, type: :string, description: 'User ID or "current" (recommended)'
      parameter name: :heartbeats, in: :body, schema: {
        type: :array,
        items: {
          type: :object,
          properties: {
            entity: { type: :string },
            type: { type: :string },
            time: { type: :number },
            project: { type: :string },
            branch: { type: :string },
            language: { type: :string },
            is_write: { type: :boolean },
            lineno: { type: :integer },
            cursorpos: { type: :integer },
            lines: { type: :integer },
            category: { type: :string }
          }
        }
      }

      response(202, 'accepted') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:id) { 'current' }
        let(:heartbeats) { [ { entity: 'file.rb', time: Time.now.to_f, language: 'Ruby', is_write: true } ] }
        schema type: :object,
          properties: {
            id: { type: :integer },
            entity: { type: :string },
            type: { type: :string, nullable: true },
            time: { type: :number },
            project: { type: :string, nullable: true },
            branch: { type: :string, nullable: true },
            language: { type: :string, nullable: true },
            is_write: { type: :boolean, nullable: true },
            lineno: { type: :integer, nullable: true },
            cursorpos: { type: :integer, nullable: true },
            lines: { type: :integer, nullable: true },
            category: { type: :string },
            created_at: { type: :string, format: :date_time },
            user_id: { type: :integer },
            editor: { type: :string, nullable: true },
            operating_system: { type: :string, nullable: true },
            machine: { type: :string, nullable: true },
            user_agent: { type: :string, nullable: true },
            verified: { type: :boolean },
            trust_score: { type: :number },
            trust_reasons: {
              type: :array,
              items: { type: :string }
            }
          }
        run_test! do |response|
          data = parsed_body(response)
          expect(data["verified"]).to eq(true)
          expect(data["trust_score"]).to be >= 0.7
          expect(data["trust_reasons"]).to eq([])
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { 'invalid' }
        let(:id) { 'current' }
        let(:heartbeats) { [] }
        run_test!
      end
    end
  end

  path '/api/hackatime/v1/users/{id}/statusbar/today' do
    get('Get status bar today') do
      tags 'WakaTime Compatibility'
      description 'Returns the total coding time for today. Used by editor plugins to display the status bar widget.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :id, in: :path, type: :string, description: 'User ID or "current"'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:id) { 'current' }
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                grand_total: {
                  type: :object,
                  properties: {
                    total_seconds: { type: :number, example: 7200.0 },
                    text: { type: :string, example: '2h 30m / 4h today' }
                  }
                },
                raw_total_seconds: { type: :number, example: 10800.0 },
                verified_total_seconds: { type: :number, example: 7200.0 },
                suspicious_seconds: { type: :number, example: 3600.0 },
                goal: {
                  type: :object,
                  nullable: true,
                  properties: {
                    target_seconds: { type: :number, example: 14400 },
                    tracked_seconds: { type: :number, example: 9000 },
                    completion_percent: { type: :number, example: 62 },
                    complete: { type: :boolean, example: false }
                  }
                }
              }
            }
          }
        before do
          user = User.find_by!(slack_uid: 'TEST123456')
          user.heartbeats.delete_all

          create_heartbeat_span(user, count: 16, started_at: 35.minutes.ago, step_seconds: 120, entity: 'main.rb', language: 'Ruby', project: 'verified', is_write: true)
          create_heartbeat_span(user, count: 11, started_at: 10.minutes.ago, step_seconds: 120, entity: 'README.md', project: 'passive', is_write: false)
        end

        run_test! do |response|
          data = parsed_body(response).fetch("data")
          expect(data["grand_total"]["total_seconds"]).to eq(1800)
          expect(data["verified_total_seconds"]).to eq(1800)
          expect(data["raw_total_seconds"]).to eq(3300)
          expect(data["suspicious_seconds"]).to eq(1200)
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { 'invalid' }
        let(:id) { 'current' }
        run_test!
      end
    end
  end

  path '/api/hackatime/v1/users/current/stats/last_7_days' do
      get('Get last 7 days stats') do
        tags 'WakaTime Compatibility'
        description 'Returns coding statistics for the last 7 days. Used by some WakaTime dashboards.'
        security [ Bearer: [], ApiKeyAuth: [] ]
        produces 'application/json'

        response(200, 'successful') do
          let(:Authorization) { "Bearer dev-api-key-12345" }
          let(:api_key) { "dev-api-key-12345" }
          schema type: :object,
            properties: {
              data: {
                type: :object,
                properties: {
                  username: { type: :string },
                  user_id: { type: :string },
                  start: { type: :string, format: :date_time },
                  end: { type: :string, format: :date_time },
                  status: { type: :string },
                  total_seconds: { type: :number },
                  raw_total_seconds: { type: :number },
                  verified_total_seconds: { type: :number },
                  suspicious_seconds: { type: :number },
                  daily_average: { type: :number },
                  days_including_holidays: { type: :integer },
                  range: { type: :string },
                  human_readable_range: { type: :string },
                  human_readable_total: { type: :string },
                  human_readable_daily_average: { type: :string },
                  is_coding_activity_visible: { type: :boolean },
                  is_other_usage_visible: { type: :boolean },
                  editors: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string },
                        total_seconds: { type: :integer },
                        percent: { type: :number },
                        digital: { type: :string },
                        text: { type: :string },
                        hours: { type: :integer },
                        minutes: { type: :integer },
                        seconds: { type: :integer }
                      }
                    }
                  },
                  languages: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string },
                        total_seconds: { type: :integer },
                        percent: { type: :number },
                        digital: { type: :string },
                        text: { type: :string },
                        hours: { type: :integer },
                        minutes: { type: :integer },
                        seconds: { type: :integer }
                      }
                    }
                  },
                  machines: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string },
                        total_seconds: { type: :integer },
                        percent: { type: :number },
                        digital: { type: :string },
                        text: { type: :string },
                        hours: { type: :integer },
                        minutes: { type: :integer },
                        seconds: { type: :integer }
                      }
                    }
                  },
                  projects: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string },
                        total_seconds: { type: :integer },
                        percent: { type: :number },
                        digital: { type: :string },
                        text: { type: :string },
                        hours: { type: :integer },
                        minutes: { type: :integer },
                        seconds: { type: :integer }
                      }
                    }
                  },
                  operating_systems: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string },
                        total_seconds: { type: :integer },
                        percent: { type: :number },
                        digital: { type: :string },
                        text: { type: :string },
                        hours: { type: :integer },
                        minutes: { type: :integer },
                        seconds: { type: :integer }
                      }
                    }
                  },
                  categories: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string },
                        total_seconds: { type: :integer },
                        percent: { type: :number },
                        digital: { type: :string },
                        text: { type: :string },
                        hours: { type: :integer },
                        minutes: { type: :integer },
                        seconds: { type: :integer }
                      }
                    }
                  }
                }
              }
            }
          before do
            user = User.find_by!(slack_uid: 'TEST123456')
            user.heartbeats.delete_all

            create_heartbeat_span(user, count: 31, started_at: 4.hours.ago, step_seconds: 120, entity: 'app.ts', language: 'TypeScript', project: 'verified', is_write: true, editor: 'vscode')
            create_heartbeat_span(user, count: 21, started_at: 90.minutes.ago, step_seconds: 120, entity: 'notes.md', project: 'passive', is_write: false, editor: 'vscode')
          end

          run_test! do |response|
            data = parsed_body(response).fetch("data")
            expect(data["total_seconds"]).to eq(3600)
            expect(data["verified_total_seconds"]).to eq(3600)
            expect(data["raw_total_seconds"]).to eq(6000)
            expect(data["suspicious_seconds"]).to eq(2400)
            expect(data["projects"].map { |entry| entry["name"] }).to eq([ "verified" ])
          end
        end

        response(401, 'unauthorized') do
          let(:Authorization) { 'Bearer invalid' }
          let(:api_key) { 'invalid' }
          run_test!
        end
      end
    end
end

RSpec.describe 'Api::Hackatime::V1::Compatibility heartbeat verification', type: :request do
  it 'marks passive heartbeats as unverified' do
    post '/api/hackatime/v1/users/current/heartbeats',
      params: [ { entity: 'README.md', time: Time.now.to_f, language: nil, is_write: false } ].to_json,
      headers: {
        'CONTENT_TYPE' => 'application/json',
        'Authorization' => 'Bearer dev-api-key-12345'
      }

    expect(response).to have_http_status(:accepted)

    data = JSON.parse(response.body)
    expect(data['verified']).to eq(false)
    expect(data['trust_reasons']).to include('no_typing_signal', 'not_code_like')
  end
end
