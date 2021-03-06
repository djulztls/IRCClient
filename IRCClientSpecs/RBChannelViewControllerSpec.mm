#import "RBChannelViewController.h"
#import "RBIRCServer.h"
#import "RBIRCMessage.h"
#import "RBIRCChannel.h"

#import "UIActionSheet+allButtonTitles.h"

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

SPEC_BEGIN(RBChannelViewControllerSpec)

describe(@"RBChannelViewController", ^{
    __block RBChannelViewController *subject;
    __block RBIRCServer *server;
    
    NSString *channel = @"#foo";

    beforeEach(^{
        subject = [[RBChannelViewController alloc] init];
        [subject view];
        
        subject.channel = channel;

        server = nice_fake_for([RBIRCServer class]);
        server stub_method("nick").and_return(@"testnick");
        server stub_method("nick:").with(Arguments::any([NSString class]));
        server stub_method("oper:password:").with(Arguments::any([NSString class]), Arguments::any([NSString class]));
        server stub_method("quit");
        server stub_method("quit:").with(Arguments::any([NSString class]));
        server stub_method("mode:options:").with(Arguments::any([NSString class]), Arguments::any([NSArray class]));
        server stub_method("kick:target:").with(Arguments::any([NSString class]), Arguments::any([NSString class]));
        server stub_method("kick:target:reason:").with(Arguments::any([NSString class]), Arguments::any([NSString class]), Arguments::any([NSString class]));
        server stub_method("privmsg:contents:").with(Arguments::any([NSString class]), Arguments::any([NSString class]));
        subject.server = server;
    });
    
    describe(@"text input", ^{
        describe(@"easily input commands", ^{
            beforeEach(^{
                // UIActionSheets have exceptions with this... :/
                @try {
                    [subject.inputCommands sendActionsForControlEvents:UIControlEventTouchUpInside];
                } @catch (NSException *e) {
                    ; // nope
                }
            });
            
            it(@"should have a button which brings up a menu for possible commands", ^{
                // I actually don't think this will ever actually show..
                subject.actionSheet should_not be_nil;
            });
            
            it(@"should have a button for most of the commands listed in IRCMessageType", ^{
                NSArray *arr = [subject.actionSheet allButtonTitles];
                for (NSString *str in @[@"notice", @"mode", @"kick", @"topic", @"nick", @"quit"]) {
                    arr should contain(str);
                }
            });
            
            it(@"should prepend text to the input field when a button is pressed", ^{
                NSString *str = [subject.actionSheet buttonTitleAtIndex:1];
                [subject actionSheet:subject.actionSheet didDismissWithButtonIndex:1];
                
                [subject.input.text hasPrefix:[NSString stringWithFormat:@"/%@", str]] should be_truthy;
            });
            
            it(@"should not prepend text if cancel is pressed", ^{
                [subject actionSheet:subject.actionSheet didDismissWithButtonIndex:subject.actionSheet.cancelButtonIndex];
                
                subject.input.text.length should equal(0);
            });
            
        });
        
        it(@"should nick", ^{
            subject.input.text = @"/nick";
            [subject textFieldShouldReturn:subject.input];
            server should_not have_received("nick:");
            
            [(id<CedarDouble>)server reset_sent_messages];
            subject.input.text = @"/nick foobar";
            [subject textFieldShouldReturn:subject.input];
            server should have_received("nick:").with(@"foobar");
        });
        
        it(@"should oper", ^{
            subject.input.text = @"/oper foo";
            [subject textFieldShouldReturn:subject.input];
            server should_not have_received("oper:password:");
            
            [(id<CedarDouble>)server reset_sent_messages];
            subject.input.text = @"/oper foo bar";
            [subject textFieldShouldReturn:subject.input];
            server should have_received("oper:password:").with(@"foo", @"bar");
        });
        
        it(@"should quit", ^{
            subject.input.text = @"/quit";
            [subject textFieldShouldReturn:subject.input];
            server should have_received("quit:").with(subject.server.nick);
            
            [(id<CedarDouble>)server reset_sent_messages];
            subject.input.text = @"/quit foobar";
            [subject textFieldShouldReturn:subject.input];
            server should have_received("quit:").with(@"foobar");
        });
        
        it(@"should mode", ^{
            subject.input.text = @"/mode +b ik";
            [subject textFieldShouldReturn:subject.input];
            server should have_received("mode:options:").with(channel, @[@"+b", @"ik"]);
            
            [(id<CedarDouble>)server reset_sent_messages];
            subject.input.text = @"/mode +b ik";
            [subject textFieldShouldReturn:subject.input];
            server should have_received("mode:options:").with(channel, @[@"+b", @"ik"]);
        });
        
        it(@"should kick", ^{
            subject.input.text = @"/kick ik";
            [subject textFieldShouldReturn:subject.input];
            server should have_received("kick:target:reason:").with(channel, @"ik", subject.server.nick);
            
            [(id<CedarDouble>)server reset_sent_messages];
            subject.input.text = @"/kick ik reason";
            [subject textFieldShouldReturn:subject.input];
            server should have_received("kick:target:reason:").with(channel, @"ik", @"reason");
            
            [(id<CedarDouble>)server reset_sent_messages];
            subject.input.text = @"/kick";
            [subject textFieldShouldReturn:subject.input];
            server should_not have_received("kick:target:");
            server should_not have_received("kick:target:reason:");
        });
        
        it(@"should privmsg", ^{
            subject.input.text = @"hello world";
            [subject textFieldShouldReturn:subject.input];
            server should have_received("privmsg:contents:").with(channel, @"hello world");
        });
    });
    
    RBIRCMessage *(^createMessage)() = ^RBIRCMessage*(){
        RBIRCMessage *msg = [[RBIRCMessage alloc] init];
        msg.message = @"Hello world";
        msg.from = @"testuser";
        msg.targets = [@[channel] mutableCopy];
        msg.command = IRCMessageTypePrivmsg;
        msg.timestamp = [NSDate date];
        
        return msg;
    };
    
    describe(@"RBServerVCDelegate responses", ^{
        it(@"should change channels", ^{
            RBIRCServer *server = nice_fake_for([RBIRCServer class]);
            RBIRCChannel *ircChannel = nice_fake_for([RBIRCChannel class]);
            server stub_method("serverName").and_return(@"Test Server");
            ircChannel stub_method("name").and_return(@"#testuser");
            [subject server:server didChangeChannel:ircChannel];
            subject.channel should equal(ircChannel.name);
        });
    });
    
    describe(@"disconnects", ^{
        beforeEach(^{
            [subject IRCServerConnectionDidDisconnect:subject.server];
            subject.server stub_method("connected").and_return(NO);
        });
        
        it(@"should display disconnected", ^{
            subject.navigationItem.title should equal(@"Disconnected");
        });
        
        it(@"should still display disconnected on channel change", ^{
            RBIRCChannel *ircChannel = nice_fake_for([RBIRCChannel class]);
            ircChannel stub_method("name").and_return(@"#testchannel");
            [subject server:subject.server didChangeChannel:ircChannel];
            subject.channel should equal(ircChannel.name);
            subject.navigationItem.title should equal(@"Disconnected");
        });
        
        it(@"should disable text input", ^{
            subject.input.enabled should be_falsy;
            subject.inputCommands.enabled should be_falsy;
        });
    });
    
    describe(@"displaying messages", ^{
        __block RBIRCChannel *ircChannel;
        __block NSMutableArray *log;
        beforeEach(^{
            RBIRCServer *server = fake_for([RBIRCServer class]);
            ircChannel = nice_fake_for([RBIRCChannel class]);
            RBIRCMessage *msg = createMessage();
            log = [[NSMutableArray alloc] init];
            [log addObject:msg];
            
            ircChannel stub_method("name").and_return(channel);
            ircChannel stub_method("log").and_return(log);
            
            server stub_method("channels").and_return(@{channel: ircChannel});
            server stub_method("objectForKeyedSubscript:").and_return(ircChannel);
            
            spy_on(subject.tableView);
            
            subject.server = server;
            subject.channel = channel;
            [subject.tableView reloadData];
        });
        
        it(@"should display existing messages", ^{
            [subject tableView:subject.tableView numberOfRowsInSection:0] should equal(log.count);
            UITableViewCell *cell = [subject tableView:subject.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            cell.textLabel.attributedText.string should equal(@"testuser: Hello world");
        });
        
        it(@"should respond to incoming messages when viewing the bottom", ^{
            NSInteger i = log.count;
            [log addObject:createMessage()];
            [subject IRCServer:subject.server handleMessage:createMessage()];
            [subject tableView:subject.tableView numberOfRowsInSection:0] should equal(i + 1);
            log.count should equal(i+1);
            subject.tableView should have_received(@selector(scrollToRowAtIndexPath:atScrollPosition:animated:)).with([NSIndexPath indexPathForRow:i inSection:0], UITableViewScrollPositionBottom, YES);
        });
        
        it(@"should respond to incoming messages when not viewing the top", ^{
            for (int i = 0; i < 50; i++) {
                [log addObject:createMessage()];
            }
            [subject tableView:subject.tableView numberOfRowsInSection:0] should be_gte(50);
            [subject.tableView reloadData];
            [subject.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
            [(id<CedarDouble>)subject.tableView reset_sent_messages];
            
            [subject IRCServer:subject.server handleMessage:createMessage()];
            subject.tableView should_not have_received(@selector(scrollToRowAtIndexPath:atScrollPosition:animated:)).with([NSIndexPath indexPathForRow:log.count - 1 inSection:0], UITableViewScrollPositionBottom, YES);
        });
        
        it(@"should display new messages as they're arrived", ^{
            NSInteger rows = [subject.tableView numberOfRowsInSection:0];
            subject.channel = @"#foo";
            RBIRCMessage *msg = createMessage();
            [log addObject:msg];
            [subject IRCServer:subject.server handleMessage:msg];
            [subject.tableView numberOfRowsInSection:0] should equal(rows+1);
            
        });
    });
});

SPEC_END
