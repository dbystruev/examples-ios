# examples-ios
Examples of using Cobalt's SDKs for iOS devices.

## CubicExample
The CubicExample folder contains code for calling Cobalt's Automatic Speach Recognition system, Cubic.  It is a simple iOS app that streams audio from the device's microphone and calls the specified Cubic Server instance to transcribe it. 

It uses the SDK documented [here](https://cobaltspeech.github.io/sdk-cubic).

### Tagging New Versions

This repository has several components, and they need more than just a "vX.Y.Z"
tag on the git repo.  In particular, this repository has two go modules, one of
which depends on the other, and in order to make sure correct versions are used,
we need to follow a few careful steps to release new versions on this
repository.

Step 1: Update the version number.

In addition to the git tags, we also save the version string in a few places in
our sources.  These strings should all be updated and a new commit created.  The
git tags should then be placed on that commit once merged to master.

Decide which version you'd like to tag. For this README, let's say the next
version to tag is `1.0.1`.

Step 3: Add version tags to the sources.

```
NEW_VERSION="1.0.1"

git checkout master
git checkout -b version-update-v$NEW_VERSION
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "CubicExample/Info.plist"
agvtool next-version
git commit -m "Update version to v$NEW_VERSION"
git push origin version-update-v$NEW_VERSION
```

Step 4: Create a pull request and get changes merged to master.

Step 5: Create version tags on the latest master branch:

```
git checkout master
git pull origin master
git tag -a v$NEW_VERSION -m ''
git push origin --tags
```
