//
//  RBIRCServer.m
//  IRCClient
//
//  Created by Rachel Brindle on 1/15/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

#import "RBIRCServer.h"
#import "RBIRCMessage.h"
#import "RBIRCChannel.h"

@interface RBIRCServer ()
{
    NSString *standardPrefix;
}

@end

@implementation RBIRCServer

-(instancetype)initWithHostname:(NSString *)hostname ssl:(BOOL)useSSL port:(NSString *)port nick:(NSString *)nick realname:(NSString *)realname
{
    if ((self = [super init]) != nil) {
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)hostname, [port intValue], &readStream, &writeStream);
        CFWriteStreamOpen(writeStream);
        CFReadStreamOpen(readStream);
        [(__bridge_transfer NSInputStream *)readStream setDelegate:self];
        channels = [[NSMutableArray alloc] init];
        [self connect:realname];
    }
    return self;
}

-(void)sendCommand:(NSString *)command
{
    command = [command stringByAppendingString:@"\r\n"];
    signed long numBytesWritten = CFWriteStreamWrite(writeStream, (const unsigned char *)[command UTF8String], [command length]);
    if (numBytesWritten < 0) {
        CFErrorRef error = CFWriteStreamCopyError(writeStream);
        NSLog(@"Error Writing to stream: %@", (__bridge_transfer NSError *)error);
    } else if (numBytesWritten == 0) {
        if (CFWriteStreamGetStatus(writeStream) == kCFStreamStatusAtEnd) {
            [self.delegate IRCServerConnectionDidDisconnect:self];
        }
    } else if (numBytesWritten != [command length]) {
        NSString *cmd = [command substringWithRange:NSMakeRange(numBytesWritten, [command length] - (2 + numBytesWritten))];
        [self sendCommand:cmd];
    }
}

-(void)connect:(NSString *)realname
{
    [self connect:realname withPassword:nil];
}

-(void)connect:(NSString *)realname withPassword:(NSString *)pass
{
    if (pass != nil || [pass length] > 0) {
        [self sendCommand:[@"pass " stringByAppendingString:pass]];
    }
    [self nick:nick];
    [self sendCommand:[NSString stringWithFormat:@"user %@ foo bar %@", nick, realname]];
}

-(void)receivedString:(NSString *)str
{
    if ([str hasPrefix:@"PING"]) { // quickly handle pings.
        [self sendCommand:[str stringByReplacingOccurrencesOfString:@"PING" withString:@"PONG"]];
    } else {
        RBIRCMessage *msg = [[RBIRCMessage alloc] initWithRawMessage:str];
        RBIRCChannel *ch = [[RBIRCChannel alloc] initWithName:[msg to]];
        if ([channels containsObject:ch]) {
            RBIRCChannel *channel = channels[[channels indexOfObject:ch]];
            [channel logMessage:msg];
        } else {
            [channels addObject:ch];
            [ch logMessage:msg];
        }
    }
}

-(void)dealloc
{
    CFReadStreamClose(readStream);
    CFWriteStreamClose(writeStream);
    CFRelease(readStream);
    CFRelease(writeStream);
    readStream = NULL;
    writeStream = NULL;
}

#pragma mark - IRC Commands

-(void)nick:(NSString *)desiredNick
{
    nick = desiredNick;
    [self sendCommand:[@"nick " stringByAppendingString:nick]];
}

-(void)oper:(NSString *)user password:(NSString *)password
{
    [self sendCommand:[NSString stringWithFormat:@"oper %@ %@", user, password]];
}

-(void)quit
{
    [self quit:@"IRCClient"];
}

-(void)quit:(NSString *)quitMessage
{
    [self sendCommand:[NSString stringWithFormat:@"quit %@", quitMessage]];
}

-(void)join:(NSString *)channelName Password:(NSString *)pass
{
    NSString *cmd = [NSString stringWithFormat:@"JOIN %@", channelName];
    if (pass) {
        cmd = [cmd stringByAppendingString:[NSString stringWithFormat:@" %@", pass]];
    }
    [self sendCommand:cmd];
    [channels addObject:channelName];
}

-(void)part:(NSString *)channel
{
    [self part:channel message:@"IRCClient"];
}

-(void)part:(NSString *)channel message:(NSString *)message
{
    [self sendCommand:[NSString stringWithFormat:@"part %@ %@", channel, message]];
}

-(void)channelMode:(NSString *)channel options:(NSString *)options
{
    [self sendCommand:[NSString stringWithFormat:@"mode %@ %@", channel, options]];
}

-(void)topic:(NSString *)channel topic:(NSString *)topic
{
    [self sendCommand:[NSString stringWithFormat:@"topic %@ %@", channel, topic]];
}

#pragma mark - NSStreamDelegate

-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable: {
            uint8_t buffer[513];
            buffer[512] = 0;
            signed long numBytesRead = CFReadStreamRead(readStream, buffer, 512);
            do {
                if (numBytesRead > 0) {
                    NSString *str = [NSString stringWithUTF8String:(const char *)buffer];
                    [self receivedString:str];
                    
                } else if (numBytesRead < 0) {
                    [self.delegate IRCServer:self errorReadingFromStream:(__bridge_transfer NSError *)CFReadStreamCopyError(readStream)];
                    //CFErrorRef error = CFReadStreamCopyError(readStream);
                    //NSLog(@"Error reading from stream: %@", (__bridge_transfer NSError *)error);
                }
            } while (numBytesRead > 0);
            break;
        } default:
            break;
    }
}

@end