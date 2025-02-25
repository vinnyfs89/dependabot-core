# frozen_string_literal: true

require "spec_helper"
require "dependabot/npm_and_yarn/file_fetcher"
require_common_spec "file_fetchers/shared_examples_for_file_fetchers"

RSpec.describe Dependabot::NpmAndYarn::FileFetcher do
  it_behaves_like "a dependency file fetcher"

  let(:source) do
    Dependabot::Source.new(
      provider: "github",
      repo: "gocardless/bump",
      directory: directory
    )
  end
  let(:file_fetcher_instance) do
    described_class.new(source: source, credentials: credentials)
  end
  let(:url) { "https://api.github.com/repos/gocardless/bump/contents/" }
  let(:directory) { "/" }
  let(:credentials) do
    [{
      "type" => "git_source",
      "host" => "github.com",
      "username" => "x-access-token",
      "password" => "token"
    }]
  end
  let(:json_header) { { "content-type" => "application/json" } }

  before do
    allow(file_fetcher_instance).to receive(:commit).and_return("sha")

    stub_request(:get, url + "?ref=sha").
      with(headers: { "Authorization" => "token token" }).
      to_return(
        status: 200,
        body: fixture("github", "contents_js_npm.json"),
        headers: json_header
      )

    stub_request(:get, File.join(url, "package.json?ref=sha")).
      with(headers: { "Authorization" => "token token" }).
      to_return(
        status: 200,
        body: fixture("github", "package_json_content.json"),
        headers: json_header
      )

    stub_request(:get, File.join(url, "package-lock.json?ref=sha")).
      with(headers: { "Authorization" => "token token" }).
      to_return(
        status: 200,
        body: fixture("github", "package_lock_content.json"),
        headers: json_header
      )
  end

  context "with a .npmrc file" do
    before do
      stub_request(:get, url + "?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "contents_js_npm_with_config.json"),
          headers: json_header
        )

      stub_request(:get, File.join(url, ".npmrc?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "npmrc_content.json"),
          headers: json_header
        )
    end

    it "fetches the .npmrc" do
      expect(file_fetcher_instance.files.count).to eq(3)
      expect(file_fetcher_instance.files.map(&:name)).to include(".npmrc")
      expect(file_fetcher_instance.files.map(&:name)).
        to include("package-lock.json")
    end

    context "that specifies no package-lock" do
      before do
        stub_request(:get, File.join(url, ".npmrc?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "npmrc_content_no_lockfile.json"),
            headers: json_header
          )
      end

      it "doesn't include the package-lock" do
        expect(file_fetcher_instance.files.count).to eq(2)
        expect(file_fetcher_instance.files.map(&:name)).to include(".npmrc")
        expect(file_fetcher_instance.files.map(&:name)).
          to_not include("package-lock.json")
      end
    end
  end

  context "without a package-lock.json file or a yarn.lock" do
    before do
      stub_request(:get, url + "?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "contents_js_library.json"),
          headers: json_header
        )
      stub_request(:get, File.join(url, "package-lock.json?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(status: 404)
    end

    it "fetches the package.json" do
      expect(file_fetcher_instance.files.map(&:name)).to eq(["package.json"])
      expect(file_fetcher_instance.files.first.type).to eq("file")
    end

    context "with a path dependency" do
      before do
        stub_request(:get, File.join(url, "package.json?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_with_path_content.json"),
            headers: json_header
          )
      end

      context "that has an unfetchable path" do
        before do
          stub_request(:get, File.join(url, "deps/etag/package.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(status: 404)
          stub_request(:get, File.join(url, "deps/etag?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(status: 404)
          stub_request(:get, File.join(url, "deps?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(status: 404)
        end

        it "fetches the package.json and ignores the missing path dep" do
          expect(file_fetcher_instance.files.map(&:name)).
            to eq(["package.json"])
          expect(file_fetcher_instance.files.first.type).to eq("file")
        end
      end
    end
  end

  context "with a yarn.lock but no package-lock.json file" do
    before do
      stub_request(:get, url + "?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "contents_js_yarn.json"),
          headers: json_header
        )
      stub_request(:get, File.join(url, "package-lock.json?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(status: 404)
      stub_request(:get, File.join(url, "yarn.lock?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "yarn_lock_content.json"),
          headers: json_header
        )
    end

    it "fetches the package.json and yarn.lock" do
      expect(file_fetcher_instance.files.map(&:name)).
        to match_array(%w(package.json yarn.lock))
    end

    context "with a .yarnrc file" do
      before do
        stub_request(:get, url + "?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "contents_js_yarn_with_config.json"),
            headers: json_header
          )

        stub_request(:get, File.join(url, ".yarnrc?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "npmrc_content.json"),
            headers: json_header
          )
      end

      it "fetches the .yarnrc" do
        expect(file_fetcher_instance.files.count).to eq(3)
        expect(file_fetcher_instance.files.map(&:name)).to include(".yarnrc")
      end
    end
  end

  context "with an npm-shrinkwrap.json but no package-lock.json file" do
    before do
      stub_request(:get, url + "?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "contents_js_shrinkwrap.json"),
          headers: json_header
        )
      stub_request(:get, File.join(url, "package-lock.json?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(status: 404)
      stub_request(:get, File.join(url, "npm-shrinkwrap.json?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "package_lock_content.json"),
          headers: json_header
        )
    end

    it "fetches the package.json and npm-shrinkwrap.json" do
      expect(file_fetcher_instance.files.map(&:name)).
        to match_array(%w(package.json npm-shrinkwrap.json))
    end
  end

  context "with a package-lock.json file but no yarn.lock" do
    before do
      stub_request(:get, url + "?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "contents_js_npm.json"),
          headers: json_header
        )
      stub_request(:get, File.join(url, "yarn.lock?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(status: 404)
      stub_request(:get, File.join(url, "package-lock.json?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "package_lock_content.json"),
          headers: json_header
        )
    end

    it "fetches the package.json and package-lock.json" do
      expect(file_fetcher_instance.files.map(&:name)).
        to match_array(%w(package.json package-lock.json))
    end
  end

  context "with both a package-lock.json file and a yarn.lock" do
    before do
      stub_request(:get, url + "?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "contents_js_npm_and_yarn.json"),
          headers: json_header
        )
      stub_request(:get, File.join(url, "yarn.lock?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "yarn_lock_content.json"),
          headers: json_header
        )
      stub_request(:get, File.join(url, "package-lock.json?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "package_lock_content.json"),
          headers: json_header
        )
    end

    it "fetches the package.json, package-lock.json and yarn.lock" do
      expect(file_fetcher_instance.files.map(&:name)).
        to match_array(%w(package.json package-lock.json yarn.lock))
    end
  end

  context "with a path dependency" do
    before do
      stub_request(:get, File.join(url, "package.json?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "package_json_with_path_content.json"),
          headers: json_header
        )
    end

    context "with a bad package.json" do
      before do
        stub_request(:get, File.join(url, "package.json?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "gemfile_content.json"),
            headers: json_header
          )
      end

      it "raises a DependencyFileNotParseable error" do
        expect { file_fetcher_instance.files }.
          to raise_error(Dependabot::DependencyFileNotParseable) do |error|
            expect(error.file_name).to eq("package.json")
          end
      end
    end

    context "with a bad dependencies object" do
      before do
        stub_request(:get, File.join(url, "package.json?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_with_dependency_arrays.json"),
            headers: json_header
          )
      end

      it "raises a DependencyFileNotParseable error" do
        expect { file_fetcher_instance.files }.
          to raise_error(Dependabot::DependencyFileNotParseable) do |error|
            expect(error.file_name).to eq("package.json")
          end
      end
    end

    context "that has a fetchable path" do
      before do
        stub_request(:get, File.join(url, "deps/etag/package.json?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
      end

      it "fetches package.json from path dependency" do
        expect(file_fetcher_instance.files.count).to eq(3)
        expect(file_fetcher_instance.files.map(&:name)).
          to include("deps/etag/package.json")
        path_file = file_fetcher_instance.files.
                    find { |f| f.name == "deps/etag/package.json" }
        expect(path_file.support_file?).to eq(true)
      end
    end

    context "that is specified as a link" do
      before do
        stub_request(:get, File.join(url, "package.json?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_with_path_link_content.json"),
            headers: json_header
          )
        stub_request(:get, File.join(url, "deps/etag/package.json?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
      end

      it "fetches package.json from path dependency" do
        expect(file_fetcher_instance.files.count).to eq(3)
        expect(file_fetcher_instance.files.map(&:name)).
          to include("deps/etag/package.json")
        path_file = file_fetcher_instance.files.
                    find { |f| f.name == "deps/etag/package.json" }
        expect(path_file.support_file?).to eq(true)
      end
    end

    context "with a tarball path dependency" do
      before do
        stub_request(:get, File.join(url, "package.json?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_with_tarball_path.json"),
            headers: json_header
          )
        stub_request(:get, "https://api.github.com/repos/gocardless/bump/"\
                           "contents/deps/etag.tgz?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 403,
            body: fixture("github", "file_too_large.json"),
            headers: json_header
          )
        stub_request(:get, "https://api.github.com/repos/gocardless/bump/"\
                            "contents/deps?ref=sha").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "contents_js_tarball.json"),
            headers: json_header
          )
        stub_request(:get, "https://api.github.com/repos/gocardless/bump/git/"\
                           "blobs/2393602fac96cfe31d64f89476014124b4a13b85").
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "blob_js_tarball.json"),
            headers: json_header
          )
      end

      it "fetches the tarball path dependency" do
        expect(file_fetcher_instance.files.map(&:name)).to eq(
          ["package.json", "package-lock.json", "deps/etag.tgz"]
        )
      end
    end

    context "that has an unfetchable path" do
      before do
        stub_request(:get, File.join(url, "deps/etag/package.json?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(status: 404)
        stub_request(:get, File.join(url, "deps/etag?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(status: 404)
        stub_request(:get, File.join(url, "deps?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(status: 404)
      end

      context "when the path dep doesn't appear in the lockfile" do
        it "raises a PathDependenciesNotReachable error with details" do
          expect { file_fetcher_instance.files }.
            to raise_error(
              Dependabot::PathDependenciesNotReachable,
              "The following path based dependencies could not be retrieved: " \
              "etag"
            )
        end
      end

      context "when the path dep does appear in the lockfile" do
        before do
          stub_request(:get, File.join(url, "package-lock.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "package_lock_with_path_content.json"),
              headers: json_header
            )
        end

        it "builds an imitation path dependency" do
          expect(file_fetcher_instance.files.count).to eq(3)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("deps/etag/package.json")
          path_file = file_fetcher_instance.files.
                      find { |f| f.name == "deps/etag/package.json" }
          expect(path_file.support_file?).to eq(true)
          expect(path_file.content).
            to eq("{\"name\":\"etag\",\"version\":\"0.0.1\"}")
        end
      end

      context "that only appears in the lockfile" do
        before do
          stub_request(:get, url + "?ref=sha").
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "contents_js_npm.json"),
              headers: json_header
            )
          stub_request(:get, File.join(url, "package.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "package_json_content.json"),
              headers: json_header
            )
          stub_request(:get, File.join(url, "package-lock.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "package_lock_with_path_content.json"),
              headers: json_header
            )
        end

        it "builds an imitation path dependency" do
          expect(file_fetcher_instance.files.count).to eq(3)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("deps/etag/package.json")
          path_file = file_fetcher_instance.files.
                      find { |f| f.name == "deps/etag/package.json" }
          expect(path_file.support_file?).to eq(true)
        end
      end
    end
  end

  context "with a path dependency in a yarn resolution" do
    before do
      stub_request(:get, File.join(url, "package.json?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github",
                        "package_json_with_yarn_resolution_file_content.json"),
          headers: json_header
        )
    end

    context "that has a fetchable path" do
      before do
        file_url = File.join(url, "mocks/sprintf-js/package.json?ref=sha")
        stub_request(:get, file_url).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
      end

      it "fetches package.json from path dependency" do
        expect(file_fetcher_instance.files.count).to eq(3)
        expect(file_fetcher_instance.files.map(&:name)).
          to include("mocks/sprintf-js/package.json")
        path_file = file_fetcher_instance.files.
                    find { |f| f.name == "mocks/sprintf-js/package.json" }
        expect(path_file.support_file?).to eq(true)
      end
    end

    context "that has an unfetchable path" do
      before do
        file_url = File.join(url, "mocks/sprintf-js/package.json?ref=sha")
        stub_request(:get, file_url).
          with(headers: { "Authorization" => "token token" }).
          to_return(status: 404)
        stub_request(:get, File.join(url, "mocks/sprintf-js?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(status: 404)
        stub_request(:get, File.join(url, "mocks?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(status: 404)
      end

      context "when the path dep doesn't appear in the lockfile" do
        it "raises a PathDependenciesNotReachable error with details" do
          expect { file_fetcher_instance.files }.
            to raise_error(
              Dependabot::PathDependenciesNotReachable,
              "The following path based dependencies could not be retrieved: " \
              "sprintf-js"
            )
        end
      end

      context "when the path dep does appear in the lockfile" do
        before do
          stub_request(:get, url + "?ref=sha").
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "contents_js_yarn.json"),
              headers: json_header
            )
          stub_request(:get, File.join(url, "package-lock.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(status: 404)
          stub_request(:get, File.join(url, "yarn.lock?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "yarn_lock_with_path_content.json"),
              headers: json_header
            )
        end

        it "builds an imitation path dependency" do
          expect(file_fetcher_instance.files.map(&:name)).to match_array(
            %w(package.json yarn.lock mocks/sprintf-js/package.json)
          )
          path_file = file_fetcher_instance.files.
                      find { |f| f.name == "mocks/sprintf-js/package.json" }
          expect(path_file.support_file?).to eq(true)
          expect(path_file.content).
            to eq("{\"name\":\"sprintf-js\",\"version\":\"0.0.0\"}")
        end
      end
    end
  end

  context "with a lerna.json file" do
    before do
      stub_request(:get, url + "?ref=sha").
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "contents_js_npm_lerna.json"),
          headers: json_header
        )
      stub_request(:get, File.join(url, "lerna.json?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "lerna_content.json"),
          headers: json_header
        )
    end

    context "that have fetchable paths" do
      before do
        stub_request(:get, File.join(url, "packages?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "packages_files.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package1/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package1?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "contents_js_library.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package2/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package2?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "contents_js_library.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "other_package/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "other_package?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "contents_js_library.json"),
            headers: json_header
          )
      end

      it "fetches the lerna.json" do
        expect(file_fetcher_instance.files.count).to eq(6)
        expect(file_fetcher_instance.files.map(&:name)).to include("lerna.json")
      end

      it "fetches package.jsons for the dependencies" do
        expect(file_fetcher_instance.files.count).to eq(6)
        expect(file_fetcher_instance.files.map(&:name)).
          to include("packages/package2/package.json")
      end

      context "with two stars to expand (not one)" do
        before do
          stub_request(:get, File.join(url, "lerna.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "lerna_content_two_stars.json"),
              headers: json_header
            )
        end

        it "fetches the lerna.json and package.jsons" do
          expect(file_fetcher_instance.files.count).to eq(6)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("packages/package2/package.json")
        end

        context "and a deeply nested package" do
          before do
            stub_request(
              :get,
              File.join(url, "packages/package1/package.json?ref=sha")
            ).with(headers: { "Authorization" => "token token" }).
              to_return(status: 404)
            stub_request(
              :get,
              File.join(url, "packages/package1?ref=sha")
            ).with(headers: { "Authorization" => "token token" }).
              to_return(
                status: 200,
                body: fixture("github", "packages_files_nested2.json"),
                headers: json_header
              )
            stub_request(
              :get,
              File.join(url, "packages/package1/package1?ref=sha")
            ).with(headers: { "Authorization" => "token token" }).
              to_return(
                status: 200,
                body: fixture("github", "contents_js_library.json"),
                headers: json_header
              )
            stub_request(
              :get,
              File.join(url, "packages/package1/package2?ref=sha")
            ).with(headers: { "Authorization" => "token token" }).
              to_return(
                status: 200,
                body: fixture("github", "contents_python_repo.json"),
                headers: json_header
              )
            stub_request(
              :get,
              File.join(url, "packages/package1/package2/package.json?ref=sha")
            ).with(headers: { "Authorization" => "token token" }).
              to_return(status: 404)
            stub_request(
              :get,
              File.join(url, "packages/package1/package1/package.json?ref=sha")
            ).with(headers: { "Authorization" => "token token" }).
              to_return(
                status: 200,
                body: fixture("github", "package_json_content.json"),
                headers: json_header
              )
          end

          it "fetches the nested package.jsons" do
            expect(file_fetcher_instance.files.count).to eq(6)
            expect(file_fetcher_instance.files.map(&:name)).
              to include("packages/package1/package1/package.json")
          end
        end
      end

      context "with a glob that specifies only the second package" do
        before do
          stub_request(:get, File.join(url, "lerna.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "lerna_content_specific.json"),
              headers: json_header
            )
        end

        it "fetches the lerna.json and package.jsons" do
          expect(file_fetcher_instance.files.count).to eq(5)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("packages/package2/package.json")
          expect(file_fetcher_instance.files.map(&:name)).
            to_not include("packages/package/package.json")
        end
      end

      context "with a glob that prefixes the packages names" do
        before do
          stub_request(:get, File.join(url, "lerna.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "lerna_content_prefix.json"),
              headers: json_header
            )
        end

        it "fetches the lerna.json and package.jsons" do
          expect(file_fetcher_instance.files.count).to eq(6)
        end
      end

      context "with a lockfile for one of the packages" do
        before do
          stub_request(
            :get,
            File.join(url, "other_package?ref=sha")
          ).with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "contents_js_npm.json"),
              headers: json_header
            )
          stub_request(
            :get,
            File.join(url, "other_package/package-lock.json?ref=sha")
          ).with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "package_lock_content.json"),
              headers: json_header
            )
        end

        it "fetches the lockfile" do
          expect(file_fetcher_instance.files.count).to eq(7)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("other_package/package-lock.json")
        end
      end

      context "in a directory" do
        let(:url) do
          "https://api.github.com/repos/gocardless/bump/contents/etc"
        end
        let(:directory) { "/etc" }
        before do
          stub_request(:get, File.join(url, "packages?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "packages_files_nested.json"),
              headers: json_header
            )
          stub_request(
            :get,
            "https://api.github.com/repos/gocardless/bump/contents/"\
            ".npmrc?ref=sha"
          ).with(headers: { "Authorization" => "token token" }).
            to_return(status: 404)
          stub_request(
            :get,
            "https://api.github.com/repos/gocardless/bump/contents/"\
            ".yarnrc?ref=sha"
          ).with(headers: { "Authorization" => "token token" }).
            to_return(status: 404)
        end

        it "fetches package.json from the workspace dependencies" do
          expect(file_fetcher_instance.files.count).to eq(6)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("packages/package2/package.json")
        end
      end
    end

    context "that has an unfetchable path" do
      before do
        stub_request(:get, File.join(url, "packages?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "packages_files.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package1/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package1?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "contents_js_library.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package2/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package2?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "contents_js_library.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "other_package/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 404,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
      end

      it "fetches package.json from the workspace dependencies it can" do
        expect(file_fetcher_instance.files.count).to eq(5)
        expect(file_fetcher_instance.files.map(&:name)).
          to include("packages/package2/package.json")
        expect(file_fetcher_instance.files.map(&:name)).
          to_not include("other_package/package.json")
      end
    end
  end

  context "with workspaces" do
    before do
      allow(file_fetcher_instance).to receive(:commit).and_return("sha")

      stub_request(:get, File.join(url, "package.json?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "package_json_with_workspaces_content.json"),
          headers: json_header
        )

      stub_request(:get, File.join(url, "yarn.lock?ref=sha")).
        with(headers: { "Authorization" => "token token" }).
        to_return(
          status: 200,
          body: fixture("github", "yarn_lock_content.json"),
          headers: json_header
        )
    end

    context "that have fetchable paths" do
      before do
        stub_request(:get, File.join(url, "packages?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "packages_files.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package1/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package2/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "other_package/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
      end

      it "fetches package.json from the workspace dependencies" do
        expect(file_fetcher_instance.files.count).to eq(5)
        expect(file_fetcher_instance.files.map(&:name)).
          to include("packages/package2/package.json")

        workspace_dep =
          file_fetcher_instance.files.
          find { |f| f.name == "packages/package1/package.json" }
        expect(workspace_dep.type).to eq("file")
      end

      context "specified using './packages/*'" do
        before do
          stub_request(:get, File.join(url, "package.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body:
                fixture("github", "package_json_with_relative_workspaces.json"),
              headers: json_header
            )
        end

        it "fetches package.json from the workspace dependencies" do
          expect(file_fetcher_instance.files.count).to eq(5)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("packages/package2/package.json")

          workspace_dep =
            file_fetcher_instance.files.
            find { |f| f.name == "packages/package1/package.json" }
          expect(workspace_dep.type).to eq("file")
        end
      end

      context "specified using a hash" do
        before do
          stub_request(:get, File.join(url, "package.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "package_json_with_hash_workspaces.json"),
              headers: json_header
            )
        end

        it "fetches package.json from the workspace dependencies" do
          expect(file_fetcher_instance.files.count).to eq(5)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("packages/package2/package.json")
        end

        context "that excludes a workspace" do
          before do
            stub_request(:get, File.join(url, "package.json?ref=sha")).
              with(headers: { "Authorization" => "token token" }).
              to_return(
                status: 200,
                body: fixture(
                  "github",
                  "package_json_with_exclusion_workspace.json"
                ),
                headers: json_header
              )
          end

          it "fetches package.json from the workspace dependencies" do
            expect(file_fetcher_instance.files.map(&:name)).
              to match_array(
                %w(
                  package.json
                  package-lock.json
                  packages/package1/package.json
                )
              )
          end
        end

        context "that uses nohoist" do
          before do
            stub_request(:get, File.join(url, "package.json?ref=sha")).
              with(headers: { "Authorization" => "token token" }).
              to_return(
                status: 200,
                body: fixture(
                  "github",
                  "package_json_with_nohoist_workspaces_content.json"
                ),
                headers: json_header
              )
          end

          it "fetches package.json from the workspace dependencies" do
            expect(file_fetcher_instance.files.count).to eq(5)
            expect(file_fetcher_instance.files.map(&:name)).
              to include("packages/package2/package.json")
          end
        end
      end

      context "specified with a top-level wildcard" do
        before do
          stub_request(:get, File.join(url, "package.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body:
                fixture("github", "package_json_with_wildcard_workspace.json"),
              headers: json_header
            )

          %w(build_scripts data migrations tests).each do |dir|
            stub_request(:get, url + "#{dir}/package.json?ref=sha").
              with(headers: { "Authorization" => "token token" }).
              to_return(status: 404, headers: json_header)
          end

          stub_request(:get, File.join(url, "app/package.json?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "package_json_content.json"),
              headers: json_header
            )
        end

        it "fetches package.json from the workspace dependencies" do
          expect(file_fetcher_instance.files.count).to eq(4)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("app/package.json")
        end
      end

      context "with a path dependency" do
        before do
          stub_request(
            :get,
            File.join(url, "packages/package2/package.json?ref=sha")
          ).with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "package_json_with_path_content.json"),
              headers: json_header
            )

          stub_request(
            :get,
            File.join(url, "packages/package2/deps/etag/package.json?ref=sha")
          ).with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "package_json_content.json"),
              headers: json_header
            )
        end

        it "fetches package.json from the workspace dependencies" do
          expect(file_fetcher_instance.files.count).to eq(6)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("packages/package2/deps/etag/package.json")
        end
      end

      context "including an empty folder" do
        before do
          stub_request(
            :get,
            File.join(url, "packages/package2/package.json?ref=sha")
          ).with(headers: { "Authorization" => "token token" }).
            to_return(status: 404)
        end

        it "fetches the other workspaces, ignoring the empty folder" do
          expect(file_fetcher_instance.files.count).to eq(4)
          expect(file_fetcher_instance.files.map(&:name)).
            to_not include("packages/package2/package.json")
        end
      end

      context "in a directory" do
        let(:url) do
          "https://api.github.com/repos/gocardless/bump/contents/etc"
        end
        let(:directory) { "/etc" }
        before do
          stub_request(:get, File.join(url, "packages?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "packages_files_nested.json"),
              headers: json_header
            )
          stub_request(
            :get,
            "https://api.github.com/repos/gocardless/bump/contents/"\
            ".npmrc?ref=sha"
          ).with(headers: { "Authorization" => "token token" }).
            to_return(status: 404)
          stub_request(
            :get,
            "https://api.github.com/repos/gocardless/bump/contents/"\
            ".yarnrc?ref=sha"
          ).with(headers: { "Authorization" => "token token" }).
            to_return(status: 404)
        end

        it "fetches package.json from the workspace dependencies" do
          expect(file_fetcher_instance.files.count).to eq(5)
          expect(file_fetcher_instance.files.map(&:name)).
            to include("packages/package2/package.json")
        end

        context "and an npmrc file in the parent directory" do
          before do
            stub_request(
              :get,
              "https://api.github.com/repos/gocardless/bump/contents/"\
              ".npmrc?ref=sha"
            ).with(headers: { "Authorization" => "token token" }).
              to_return(
                status: 200,
                body: fixture("github", "npmrc_content.json"),
                headers: json_header
              )
          end

          it "fetches the npmrc file" do
            expect(file_fetcher_instance.files.count).to eq(6)
            expect(file_fetcher_instance.files.map(&:name)).
              to include("../.npmrc")
          end
        end
      end
    end

    context "that has an unfetchable path" do
      before do
        stub_request(:get, File.join(url, "packages?ref=sha")).
          with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "packages_files.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package1/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "packages/package2/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(
            status: 200,
            body: fixture("github", "package_json_content.json"),
            headers: json_header
          )
        stub_request(
          :get,
          File.join(url, "other_package/package.json?ref=sha")
        ).with(headers: { "Authorization" => "token token" }).
          to_return(status: 404, headers: json_header)
      end

      it "fetches package.json from the workspace dependencies it can" do
        expect(file_fetcher_instance.files.count).to eq(4)
        expect(file_fetcher_instance.files.map(&:name)).
          to include("packages/package2/package.json")
        expect(file_fetcher_instance.files.map(&:name)).
          to_not include("other_package/package.json")
      end

      context "because one of the repos isn't fetchable" do
        before do
          stub_request(:get, File.join(url, "packages?ref=sha")).
            with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 404,
              headers: json_header
            )

          stub_request(
            :get,
            File.join(url, "other_package/package.json?ref=sha")
          ).with(headers: { "Authorization" => "token token" }).
            to_return(
              status: 200,
              body: fixture("github", "package_json_content.json"),
              headers: json_header
            )
        end

        it "fetches package.json from the workspace dependencies it can" do
          expect(file_fetcher_instance.files.count).to eq(4)
          expect(file_fetcher_instance.files.map(&:name)).
            to_not include("packages/package2/package.json")
          expect(file_fetcher_instance.files.map(&:name)).
            to include("other_package/package.json")
        end
      end
    end
  end
end
