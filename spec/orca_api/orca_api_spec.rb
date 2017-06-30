# coding: utf-8

require "spec_helper"

# 日レセAPIの実行結果のうち、実行日時のような実行時に決定する値以外が等しいかどうかを検証する
RSpec::Matchers.define :be_api_result_equal_to do |expected|
  exclude_keys = %w(
    Information_Date
    Information_Time
  )
  match do |actual|
    response_name = expected.keys.first
    exclude_keys.each do |k|
      expected[response_name][k] = actual[response_name][k]
    end
    actual == expected
  end

  diffable
end

RSpec.describe OrcaApi::OrcaApi do
  describe ".new" do
    let(:options) { ["example.com", double("authentication"), 18000] }

    subject { OrcaApi::OrcaApi.new(*options) }

    its(:host) { is_expected.to eq(options[0]) }
    its(:authentication) { is_expected.to eq(options[1]) }
    its(:port) { is_expected.to eq(options[2]) }

    describe "portは省略可能" do
      let(:options) { ["example.com", double("authentication")] }

      its(:port) { is_expected.to eq(8000) }
    end
  end

  describe "#call" do
    let(:options) { ["example.com", authentication, 18000] }
    let(:url) { "#{http_scheme}://#{options[0]}:#{options[2]}" }
    let(:orca_api) { OrcaApi::OrcaApi.new(*options) }
    let(:result) {
      fixture_name = path[1..-1].gsub("/", "_") + ".json"
      fixture_path = File.expand_path(File.join("../../fixtures/orca_api_results", fixture_name), __FILE__)
      eval(File.read(fixture_path))
    }

    subject {
      orca_api.call(path, params: params, body: body, http_method: http_method)
    }

    before do
      query = params.merge(format: "json").map { |k, v| "#{k}=#{v}" }.join("&")
      stub_request(http_method, URI.join(url, path, "?#{query}"))
        .with(body: body.empty? ? nil : body.to_json)
        .to_return(body: result.to_json)
    end

    shared_examples "日レセAPIを呼び出せること" do
      describe "/api01rv2/patientgetv2" do
        let(:path) { "/api01rv2/patientgetv2" }
        let(:params) {
          { id: "1" }
        }
        let(:body) {
          {}
        }
        let(:http_method) { :get }

        it { is_expected.to be_api_result_equal_to(result) }
      end

      describe "/api01rv2/patientlst1v2" do
        let(:path) { "/api01rv2/patientlst1v2" }
        let(:params) {
          { "class" => "01" }
        }
        let(:body) {
          {
            "patientlst1req" => {
              "Base_StartDate" => "2012-06-01",
              "Base_EndDate" => "2012-06-30",
              "Contain_TestPatient_Flag" => 1,
            }
          }
        }
        let(:http_method) { :post }

        it { is_expected.to be_api_result_equal_to(result) }
      end
    end

    context "BASIC認証" do
      let(:authentication) { OrcaApi::OrcaApi::BasicAuthentication.new("ormaster", "ormaster") }
      let(:http_scheme) { "http" }

      include_examples "日レセAPIを呼び出せること"
    end

    context "SSLクライアント認証" do
      let(:authentication) {
        auth = OrcaApi::OrcaApi::SslClientAuthentication.new("ca_file", "cert_path", "key_path")
        allow(auth).to receive(:cert).and_return("cert")
        allow(auth).to receive(:key).and_return("key")
        auth
      }
      let(:http_scheme) { "https" }

      include_examples "日レセAPIを呼び出せること"
    end
  end
end
