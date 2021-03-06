#import "RBIRCMessage.h"
#import "NSString+isNilOrEmpty.h"

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

SPEC_BEGIN(RBIRCMessageSpec)

describe(@"RBIRCMessage", ^{
    __block RBIRCMessage *msg;
    
    RBIRCMessage *(^createMsg)(NSString *) = ^RBIRCMessage *(NSString *str){
        str = [NSString stringWithFormat:@"%@\r\n", str];
        RBIRCMessage *ret = [[RBIRCMessage alloc] initWithRawMessage:str];
        //NSLog(@"%@", ret.debugDescription);
        return ret;
    };

    it(@"should interpret joins properly", ^{
        msg = createMsg(@":foobar!foo@hide-ECFE1E4F.dsl.mindspring.com JOIN #boats");
        msg.message.hasContent should be_falsy;
        msg.from should equal(@"foobar");
        msg.targets[0] should equal(@"#boats");
        msg.command should equal(IRCMessageTypeJoin);
    });
    
    it(@"should interpret private messages properly", ^{
        msg = createMsg(@":ik!iank@hide-1664EBC6.iank.org PRIVMSG #boats :how are you");
        msg.message should equal(@"how are you");
        msg.from should equal(@"ik");
        msg.targets[0] should equal(@"#boats");
        msg.command should equal(IRCMessageTypePrivmsg);
    });
    
    it(@"should interpret notices properly", ^{
        msg = createMsg(@":You!Rachel@hide-DEA18147.com NOTICE foobar :test");
        msg.message should equal(@"test");
        msg.from should equal(@"You");
        msg.targets[0] should equal(@"foobar");
        msg.command should equal(IRCMessageTypeNotice);
    });
    
    it(@"should interpret parts properly", ^{
        msg = createMsg(@":You!Rachel@hide-DEA18147.com PART #foo :test");
        msg.message should equal(@"test");
        msg.from should equal(@"You");
        msg.targets[0] should equal(@"#foo");
        msg.command should equal(IRCMessageTypePart);
    });
    
    it(@"should interpret modes properly", ^{
        msg = createMsg(@":You!Rachel@hide-DEA18147.com MODE #foo +b foobar!*@*");
        msg.message should equal(@"+b foobar!*@*");
        msg.extra should be_instance_of([NSArray class]).or_any_subclass();
        msg.extra[0] should equal(@[@"+b"]);
        msg.extra[1] should equal(@"foobar!*@*");
        msg.from should equal(@"You");
        msg.targets[0] should equal(@"#foo");
        msg.command should equal(IRCMessageTypeMode);
        
        msg = createMsg(@":YouiOS MODE YouiOS :+iwxz");
        msg.message should equal(@"+iwxz");
        msg.extra should be_instance_of([NSArray class]).or_any_subclass();
        msg.extra[0] should equal(@[@"+iwxz"]);
        msg.targets[0] should equal(@"YouiOS");
        msg.from should equal(@"YouiOS");
        msg.command should equal(IRCMessageTypeMode);
    });
    
    it(@"should interpret kicks properly", ^{
        msg = createMsg(@":You!Rachel@hide-DEA18147.com KICK #foo foobar :You");
        msg.message should equal(@"foobar :You");
        msg.extra should be_instance_of([NSDictionary class]).or_any_subclass();
        msg.from should equal(@"You");
        msg.targets[0] should equal(@"#foo");
        msg.command should equal(IRCMessageTypeKick);
    });
    
    it(@"should interpret pings properly", ^{
        msg = createMsg(@"PING :EF0896");
        msg.message should equal(@"EF0896");
    });
});

SPEC_END
