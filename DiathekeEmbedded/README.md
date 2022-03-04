# Diatheke Embedded Demo Reference

This example illustrates running all the Cobalt engines on an iOS device rather than accessing them in the cloud.
As such, it requires additional steps to set up frameworks for Luna (TTS), Diatheke (Dialogue/NLU), and Cubic (ASR).
This example also includes logic for downloading Dialogue and ASR models from a remote URL.  This makes the code example more complex, but shows how the model is independent from the code used to interact with it so the same app could potentially serve up a different logical flow just by changing out the model.

# CobaltMobile Xcode Framework Reference

CobaltMobile Xcode Framework (`Cobaltmobile.xcframework`) is an SDK containing `Diatheke` (NLU) and `Cubic` (ASR) server objects and methods to run from iOS applications.

# Requirements
Supported Platforms:

- iOS arm64
- iOS Simulator x86_64

## Minimum supported platform versions:

- iOS 9.3

## Bitcode support
Bitcode is not currently supported.

## Framework Dependencies
- `Cubic.xcframework` (provided together with CobaltMobile.xcframework). Cubic Xcode Framework is the ASR Engine required by Cubic part of the
Cobaltmobile framework. It needs to be included into Xcode project but doesn't need to be imported and used directly in any of the project's source files.

# Including the Cubic and Diatheke Framework

Add `Cobaltmobile.xcframework` and `Cubic.xcframework` to the main target of your Xcode project.

## Usage
Import `Cobaltmobile` module
``` swift
import Cobaltmobile
```
Declare and initialize `CobaltmobileCobaltFactoryProtocol` object that contains methods to create Diatheke and Cubic server objects.
``` swift
let cobaltMobile: CobaltmobileCobaltFactoryProtocol = CobaltmobileNew()
```
Create and start Cubic Server.
``` swift
var cubicServer: CobaltmobileServerProtocol?

do {
	cubicServer = try cobaltMobile.cubic("path/to/cubicsvr.cfg.toml")
	cubicServer?.start()
} catch {
	print(error)
}
```
Create and start Diatheke Server.
``` swift
var diathekeServer: CobaltmobileServerProtocol?

do {
	diathekeServer = try cobaltMobile.diatheke("path/to/diathekesvr.cfg.toml")
	diathekeServer?.start()
} catch {
	print(error)
}
```
Stop running servers.
``` swift
if diathekeServer != nil {
	diathekeServer?.stop()
	diathekeServer = nil
}

if cubicServer != nil {
	cubicServer?.stop()
	cubicServer = nil
}
```
# Server Configuration files helper tool
[CobaltKit](https://github.com/cobaltspeech/ios-app-kit) Swift Package provides convenient classes and methods to build and save Diatheke & Cubic server configuration files in TOML format. CobaltKit package contains CubicsvrConfig and DiathekeSvrConfig modules.

## Including CobaltKit Package
Go to the `Package Dependencies` tab of your Xcode project's settings and add CobaltKit Swift Package: `git@github.com:cobaltspeech/ios-app-kit.git` having the exact version v0.9.2. Check in both `CubicsvrConfig`, `LunasvrConfig` and `DiathekesvrConfig` modules. If you have your Swift package set up, adding `CobaltKit` as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.
``` swift
dependencies: [
	.package(url: "git@github.com:cobaltspeech/ios-app-kit.git", .exact("0.9.2"))
]
```
## Usage
### CubicsvrConfig
Import `CubicsvrConfig` module:
``` swift
import CubicsvrConfig
```
Init `CubicsvrConfig` object:
``` swift
var cubicServerConfig = CubicsvrConfig()
```
Or read from existing TOML string, i.e. `cubicsvr.cfg.toml` contents:
``` swift
let cubicServerConfig = CubicsvrConfig(tomlString: "{TOML string}")
```
Manage config options:
``` swift
// set path to license file
cubicServerConfig.license.KeyFile = "/path/to/cubicsvr.license.key"
// set GRPC port, i.e. 9000
cubicServerConfig.server.grpc.Address = ":9000"
// add a new model
cubicServerConfig.addModel(id: "Model ID",
						   name: "Model name",
						   path: "/path/to/model.config")
// remove a model
cubicServerConfig.removeModel(id: "Model ID")
```
> **Note**: All paths in the config should be relative to the config file path.

Save `CubicsvrConfig` object as TOML file:
``` swift
let configPath: URL = {save_path_url}
cubicServerConfig.save(configPath)
```
Full reference to Cubic Server Config File structure can be found on our [Documenation Portal](https://docs.cobaltspeech.com/asr/sdk-cubic/).

### LunasvrConfig
Import `LunasvrConfig` module:
``` swift
import LunasvrConfig
```
Init `LunasvrConfig` object:
```swift
var lunaServerConfig = LunasvrConfig()
```
Or read from existing TOML string, i.e. `lunasvr.cfg.toml` contents:
``` swift
let lunaServerConfig = LunasvrConfig(tomlString: "{TOML string}")
```
Manage config options:
``` swift
// set path to license file
cubicServerConfig.license.KeyFile = "/path/to/cubicsvr.license.key"
// set the address port, i.e. "127.0.0.1:9001"
lunaServerConfig.server.grpc.Address = "127.0.0.1:9001"
// add a new voice
lunaServerConfig.addModel(id: "Model ID", 
				  		  name: "Model name", 
						  path: "path/to/local_synth.toml")
// remove a voice
lunaServerConfig.removeModel(id: "Model ID")
```
> **Note**: All paths in the config should be absolute.

### DiathekesvrConfig
Import `DiathekesvrConfig` module:
``` swift
import DiathekesvrConfig
```
Init `DiathekesvrConfig` object:
```swift
var diathekeServerConfig = DiathekesvrConfig()
```
Or read from existing TOML string, i.e. `diathekesvr.cfg.toml` contents:
``` swift
let diathekeServerConfig = DiathekesvrConfig(tomlString: "{TOML string}")
```
Manage config options:
```swift 
// set path to license file
diathekeServerConfig.license.KeyFile = "/path/to/diathekesvr.license.key"
// set GRPC address for Diatheke server, i.e. 8181
diathekeServerConfig.server.grpc.Address = ":8181"
// set Cubic server endpoint (i.e. 9000) for Diatheke server
diathekeServerConfig.services.cubic.Address = "localhost:9000"
// all servers run on the same device so connection between them should be insecure
diathekeServerConfig.services.cubic.Insecure = true
diathekeServerConfig.services.luna.Insecure = true
// enable Cubic server for Diatheke
diathekeServerConfig.services.cubic.Enabled = true
// enable Luna server for Diatheke
diathekeServerConfig.services.luna.Enabled = true
// set Luna server endpoint (both host and port, i.e. "127.0.0.1:9001") for Diatheke server
diathekeServerConfig.services.luna.Address = "127.0.0.1:9001"
// add a new model
diathekeServerConfig.addModel(id: "Model ID",
							  name: "Model Name",
							  path: "path/to/model_config.yaml",
							  language: "en_US",
							  cubicModelID: "Cubic Model ID",
							  lunaModelID: nil,
							  transcibeModelID: "Luna Model ID")
// remove a model
diathekeServerConfig.removeModel(id: "Model ID")
```
> **Note**: All paths in the config should be relative to the config file path.

Save `DiathekesvrConfig` object as TOML file:
``` swift 
let configPath: URL = {save_path_url}
diathekeServerConfig.save(configPath)
```
More Diatheke reference can be found on our [Documenation Portal](https://docs.cobaltspeech.com/vui/sdk-diatheke/).

# Luna Xcode framework
## Including the framework and its dependencies
Luna Xcode framework and its dependencies should be downloaded and placed inside the demo project folder:
```bash
cd DiathekeEmbedded
./download_frameworks.sh 
```
## Usage
Add `LunaWrapper` C++ class to your project:
##### LunaWrapper.h
```c
#import <Foundation/Foundation.h>
@interface LunaWrapper: NSObject
- (void)startServer:(NSString *)configPath;
@end
```
##### LunaWrapper.mm
```c
#import "LunaWrapper.h"
#import <Foundation/Foundation.h>
#import "luna_server.hpp"
#include <string>

@implementation  LunaWrapper

- (void)startServer:(NSString *)configPath {
	std::string path = std::string([configPath UTF8String]);
	RunServer(path);
}

@end
```
This will automatically add a Bridging Header to your project.

#### Start Luna server
``` swift
LunaWrapper().startServer("path/to/lunasvr.cfg.toml")
```
> **Note**: Starting Luna server takes up to 8 seconds so it is better to wait this amount of time before starting Diatheke server.