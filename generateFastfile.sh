mkdir -p fastlane

cat > fastlane/Fastfile << EOL
default_platform(:ios)

platform :ios do
  desc "Push a new beta build to TestFlight if there is a new version number of build number"

  lane :update_code_signing do
    update_code_signing_settings(
        use_automatic_signing: true,
        team_id: "${TEAM_ID}"
    )
  end

  lane :beta do
    api_key = app_store_connect_api_key(
      key_id: "${APPSTORE_CONNECT_API_KEY_ID}",
      issuer_id: "${APPSTORE_CONNECT_API_ISSUER_ID}",
      key_filepath: "${APPSTORE_CONNECT_API_KEY_FILEPATH}"
    )

    update_code_signing_settings(
        use_automatic_signing: true,
        team_id: "${TEAM_ID}"
    )

    version = get_version_number(
      xcodeproj: "CubicExample.xcodeproj",
      target: "CubicExample"
    )

    build = get_build_number(xcodeproj: "CubicExample.xcodeproj")

    latest_testflight_build_number(api_key: api_key)
    testflight_version = lane_context[SharedValues::LATEST_TESTFLIGHT_VERSION]
    testflight_build_number = lane_context[SharedValues::LATEST_TESTFLIGHT_BUILD_NUMBER]

    if version == testflight_version && build.to_i == testflight_build_number
      puts "This version is already in TestFlight"
    else
      puts "Build and push a new beta build to TestFlight"
      build_app(
        scheme: "CubicExample"
      )
      upload_to_testflight(api_key: api_key)
    end
  end
end
EOL

cat > fastlane/Appfile << EOL
app_identifier("${CUBIC_DEMO_APP_IDENTIFIER}") # The bundle identifier of your app
apple_id("${APPLE_ID}") # Your Apple email address

itc_team_id("${ITC_TEAM_ID}") # App Store Connect Team ID
team_id("${TEAM_ID}") # Developer Portal Team ID
EOL
