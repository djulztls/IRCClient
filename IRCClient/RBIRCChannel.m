//
//  RBIRCChannel.m
//  IRCClient
//
//  Created by Rachel Brindle on 1/15/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

#import "RBIRCChannel.h"
#import "RBIRCServer.h"
#import "RBIRCMessage.h"

@implementation RBIRCChannel

-(instancetype)initWithName:(NSString *)name
{
    if ((self = [super init]) != nil) {
        _name = name;
        _log = [[NSMutableArray alloc] init];
        _names = [[NSMutableArray alloc] init];
    }
    return self;
}

-(BOOL)isEqual:(id)object
{
    return ([object isKindOfClass:[RBIRCChannel class]] && [[object name] isEqualToString:_name]);
}

-(void)logMessage:(RBIRCMessage *)message
{
    if (message.command == IRCMessageTypeTopic) {
        self.topic = message.message;
    } else if (message.command == IRCMessageTypeJoin) {
        if ([message.from isEqualToString:self.server.nick]) {
            // execute a /names command.
        } else {
            [self.names addObject:message.from];
        }
    } else if (message.command == IRCMessageTypePart) {
        if ([message.from isEqualToString:self.server.nick]) {
            // should not have recieved this.
            NSLog(@"Error: Recieved a self part");
        } else {
            [self.names removeObject:message.from];
        }
    }
    [_log addObject:message];
}

@end
