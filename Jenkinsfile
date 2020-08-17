#!groovy
//Copyright (2020) Cobalt Speech and Language Inc.

def build() {
	try {
		checkout scm

		commit.setBuildStatus("build", "PENDING", "Building...")
		sh "sh generateFastfile.sh"
		sh "security -i unlock-keychain -p ${USER_PASSWORD} ~/Library/Keychains/login.keychain-db"
		sh "fastlane update_code_signing"
		sh "xcodebuild test -project CubicExample.xcodeproj -scheme CubicExample -destination 'platform=iOS Simulator,name=iPhone 11'"
                sh "fastlane beta"
		commit.setBuildStatus("build", "SUCCESS", "Build succeeded")
	} catch (err) {
		commit.setBuildStatus("build", "ERROR", "Build failed")
		throw err
	} finally {
		deleteDir()
	}
}


if (env.CHANGE_ID || env.TAG_NAME) {
	// pull request or tag build
	try {
		node("ios") {
			stage("build-ios") {
				build()
			}
		}
		
		mattermostSend channel: 'g-ci-notifications', color: 'good', message: "Build Successful - ${env.JOB_NAME} ${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
	} catch (err) {
		mattermostSend channel: 'g-ci-notifications', color: 'danger', message: "Build Failed - ${env.JOB_NAME} ${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
		throw err
	}
}
