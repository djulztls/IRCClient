#import "RBServerEditorViewController.h"
#import "RBIRCServer.h"
#import "RBConfigurationKeys.h"

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

SPEC_BEGIN(RBServerEditorViewControllerSpec)

describe(@"RBServerEditorViewController", ^{
    __block RBServerEditorViewController *subject;
    __block RBIRCServer *server;

    beforeEach(^{
        subject = [[RBServerEditorViewController alloc] init];
        server = nice_fake_for([RBIRCServer class]);
        subject.server = server;
        
        spy_on(subject);
    });
    
    it(@"should name things correctly", ^{
        [subject view];
        [subject.cancelButton titleForState:UIControlStateNormal] should equal(@"Cancel");
    });
    
    it(@"should enable servername and nick always", ^{
        [subject view];
        subject.serverName.enabled should be_truthy;
        subject.serverName.enabled should be_truthy;
    });
    
    it(@"should do nothing on cancel", ^{
        [subject view];
        [subject.cancelButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        
        subject should_not have_received("save");
    });
    
    it(@"should write any changes to standard user defaults", ^{
        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:RBConfigServers];
        server = [[RBIRCServer alloc] initWithHostname:@"localhost"
                                                   ssl:YES
                                                  port:@"6697"
                                                  nick:@"testnick"
                                              realname:@"testnick"
                                              password:nil];
        subject.server = server;
        [subject view];
        [subject save];
        NSArray *a = [[NSUserDefaults standardUserDefaults] objectForKey:RBConfigServers];
        a should_not be_empty;
        RBIRCServer *s = [[RBIRCServer alloc] initWithCoder:[NSKeyedUnarchiver unarchiveObjectWithData:a.firstObject]];
        [server isEqual:s] should be_truthy;
    });
    
    describe(@"when connecting to a new server", ^{
        beforeEach(^{
            server stub_method("connected").and_return(NO);
            [subject view];
            
            server stub_method("connect");
            server stub_method("connect:");
            server stub_method("connect:withPassword:");
            
            spy_on(server);
        });
        
        it(@"should enable everything", ^{
            subject.serverHostname.enabled should be_truthy;
            subject.serverPort.enabled should be_truthy;
            subject.serverSSL.enabled should be_truthy;
            subject.serverRealName.enabled should be_truthy;
            subject.serverPassword.enabled should be_truthy;
            [subject.saveButton titleForState:UIControlStateNormal] should equal(@"Connect");
        });
        
        it(@"should not connect if no username is given", ^{
            [subject.saveButton sendActionsForControlEvents:UIControlEventTouchUpInside];
            subject should have_received("save");
            server should_not have_received("connect");
        });
        
        it(@"should connect on save", ^{
            server stub_method("nick").and_return(@"testusername");
            [subject.saveButton sendActionsForControlEvents:UIControlEventTouchUpInside];
            subject should have_received("save");
            server should have_received("connect");
        });
    });
    
    describe(@"when editing an existing server", ^{
        beforeEach(^{
            server stub_method("connected").and_return(YES);
            [subject view];
        });
        
        it(@"should gray out unchangeable things", ^{
            subject.serverHostname.enabled should be_falsy;
            subject.serverPort.enabled should be_falsy;
            subject.serverSSL.enabled should be_falsy;
            subject.serverRealName.enabled should be_falsy;
            subject.serverPassword.enabled should be_falsy;
            [subject.saveButton titleForState:UIControlStateNormal] should equal(@"Save");
        });
    });
});

SPEC_END
