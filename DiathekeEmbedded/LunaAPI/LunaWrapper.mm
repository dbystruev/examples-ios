//
//  LunaWrapper.m
//  DiathekeEmbeddedDemo
//

#import "LunaWrapper.h"
#import <Foundation/Foundation.h>
#import "luna_server.hpp"
#include <string>

@implementation LunaWrapper

- (void)startServer:(NSString *)configPath {
    std::string path = std::string([configPath UTF8String]);
    RunServer(path);
}

@end

