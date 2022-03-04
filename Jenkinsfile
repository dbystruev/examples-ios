#!groovy
//Copyright (2020) Cobalt Speech and Language Inc.

def build() {
	try {
		checkout scm

		sh "security -i unlock-keychain -p ${USER_PASSWORD} ~/Library/Keychains/login.keychain-db"

		try {
			commit.setBuildStatus("build-cubic", "PENDING", "Building...")
			sh "cd Cubic && chmod +x build.sh && ./build.sh"
			commit.setBuildStatus("build-cubic", "SUCCESS", "Build succeeded")
		} catch (err) {
			commit.setBuildStatus("build-cubic", "ERROR", "Build failed")
			throw err
		}

		/*
		// This build step performs test connection to a demo Diatheke server v2.
		// Since the current demo at demo.cobaltspeech.com runs on Diatheke v1 the test fail.
		// This build step is ready to uncomment once we have any working demo server.
		try {
			commit.setBuildStatus("build-diatheke", "PENDING", "Building...")
			sh "cd Diatheke && chmod +x build.sh && ./build.sh"
			commit.setBuildStatus("build-diatheke", "SUCCESS", "Build succeeded")
		} catch (err) {
			commit.setBuildStatus("build-diatheke", "ERROR", "Build failed")
			throw err
		}
		*/
	} catch (err) {
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
