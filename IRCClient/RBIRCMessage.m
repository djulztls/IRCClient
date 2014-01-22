//
//  RBIRCMessage.m
//  IRCClient
//
//  Created by Rachel Brindle on 1/15/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

#import "RBIRCMessage.h"

@implementation RBIRCMessage

-(instancetype)initWithRawMessage:(NSString *)raw
{
    if ((self = [super init]) != nil) {
        _rawMessage = raw;
        _timestamp = [NSDate date];
        [self parseRawMessage];
    }
    return self;
}

-(void)parseRawMessage
{
    NSArray *array = [_rawMessage componentsSeparatedByString:@" "];
    NSArray *userAndHost = [[array[0] substringFromIndex:1] componentsSeparatedByString:@"!"];
    _from = userAndHost[0];
    _command = array[1];
    _to = array[2];
    if ([array count] == 3) {
        if ([_to hasPrefix:@":"]) {
            _to = [_to substringFromIndex:1];
        }
        _message = nil;
        return;
    }
    NSString *msg = array[3];
    if ([msg hasPrefix:@":"]) {
        msg = [msg substringFromIndex:1];
    }
    for (int i = 4; i < [array count]; i++) {
        msg = [[msg stringByAppendingString:@" "] stringByAppendingString:array[i]];
    }
    _message = msg;
    if ([_command isEqualToString:@"MODE"]) { // FIXME: replace this with an enumeration.
        _extra = [_message componentsSeparatedByString:@" "];
    } else if ([_command isEqualToString:@"KICK"]) {
        NSArray *arr = [_message componentsSeparatedByString:@" "];
        _extra = @{@"target": arr[0], @"reason": [arr[1] substringFromIndex:1]};
    }
}

-(NSString *)description
{
    NSString *ret = @"";
    
    ret = [NSString stringWithFormat:@"from: %@\nto: %@\ncommand: %@\nmessage: %@", _from, _to, _command, _message];
    
    return ret;
}

@end