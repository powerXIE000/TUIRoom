//
//  TUIBarrageIMService.m
//  TUIBarrageIMService
//
//  Created by WesleyLei on 2021/9/13.
//  Copyright © 2021 wesleylei. All rights reserved.
//

#import "TUIBarrageIMService.h"
#import "MJExtension.h"
#import <ImSDK_Plus/ImSDK_Plus.h>

NSString *const TUIBARRAGEIM_DATA_VERSION = @"1.0";
NSString *const TUIBARRAGEIM_DATA_PLATFORM = @"iOS";
NSString *const TUIBARRAGEIM_DATA_BARRAGE = @"TUIBarrage";
NSString *const TUIBARRAGEIM_SIGNALING_KEY_DATA = @"data";
NSString *const TUIBARRAGEIM_SIGNALING_KEY_USERID = @"userId";
NSString *const TUIBARRAGEIM_SIGNALING_KEY_VERSION = @"version";
NSString *const TUIBARRAGEIM_SIGNALING_KEY_BUSINESSID = @"businessID";
NSString *const TUIBARRAGEIM_SIGNALING_KEY_PLATFORM = @"platform";

@interface TUIBarrageIMService ()<V2TIMSimpleMsgListener>
@property (nonatomic, weak, nullable) id <TUIBarrageIMServiceDelegate> delegate;
@property (nonatomic, weak, nullable) V2TIMManager *imManager;
@property (nonatomic, strong) NSString *groupID;
@end

@implementation TUIBarrageIMService

+ (instancetype)defaultCreate:(NSString *)groupID delegate:(id <TUIBarrageIMServiceDelegate>)delegate {
    TUIBarrageIMService *service = [[TUIBarrageIMService alloc]init];
    service.delegate = delegate;
    service.groupID = groupID;
    [service initIMListener];
    return service;
}

- (void)initIMListener {
    self.imManager = [V2TIMManager sharedInstance];
    [self.imManager addSimpleMsgListener:self];
}

#pragma mark 资源释放
///持有此对象，在dealloc时候调用此方法
- (void)releaseResources {
    [self.imManager removeSimpleMsgListener:self];
}

#pragma mark 发送Msg
/// 发送Msg
- (BOOL)onSendMsg:(NSDictionary<NSString *,id> *)param {
    ///im 发送并回调，delegate
    if ([param isKindOfClass:[NSDictionary class]] && param.count && ([self.imManager getLoginStatus] == V2TIM_STATUS_LOGINED)) {
        NSMutableDictionary *muDict = [self getMsgDict];
        NSMutableDictionary *muParam = [NSMutableDictionary dictionaryWithDictionary:param];
        muParam[TUIBARRAGEIM_SIGNALING_KEY_USERID] = [self.imManager getLoginUser]?:@"";
        muDict[TUIBARRAGEIM_SIGNALING_KEY_DATA] = param;
        [self sendGroupMsg:[muDict mj_JSONString] param:param];
        return YES;
    } else {
        return NO;
    }
}

- (void)sendGroupMsg:(NSString *)message param:(NSDictionary<NSString *,id> *)param {
    if (self.groupID.length <= 0) {
        [self sendCallBack:-1 desc:@"gourp id is wrong.please check it." param:param];
        return;
    }
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        [self sendCallBack:-1 desc:@"message can't covert to data" param:param];
        return;
    }
    NSString *textMessage = param[@"message"];
    if (!textMessage || ![textMessage isKindOfClass:[NSString class]] || textMessage.length == 0) {
        [self sendCallBack:-1 desc:@"message is empty" param:param];
        return;
    }
    __weak typeof(self) wealSelf = self;
    [self.imManager sendGroupTextMessage:textMessage to:self.groupID priority:V2TIM_PRIORITY_NORMAL succ:^{
        __strong typeof(wealSelf) strongSelf = wealSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf sendCallBack:0 desc:@"send group message success." param:param];
    } fail:^(int code, NSString *desc) {
        __strong typeof(wealSelf) strongSelf = wealSelf;
        if (!strongSelf) {
            return;
        }
        if (code == 80001) {
            [strongSelf sendCallBack:code desc:@"the word is not good" param:param];
        } else {
            [strongSelf sendCallBack:code desc:desc param:param];
        }
    }];
}

#pragma mark delegate
-(void)sendCallBack:(NSInteger)code desc:(NSString *)desc param:(NSDictionary<NSString *,id> *)param {
    if ([self.delegate respondsToSelector:@selector(didSend:isSuccess:message:)]) {
        [self.delegate didSend:param isSuccess:(code==0) message:desc];
    }
}

- (void)onReceive:(NSDictionary<NSString *,id> *)dict {
    if ([self.delegate respondsToSelector:@selector(onReceive:)]) {
        [self.delegate onReceive:dict];
    }
}

#pragma mark 消息体
///自定义消息体
- (NSMutableDictionary *)getMsgDict {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:8];
    result[TUIBARRAGEIM_SIGNALING_KEY_VERSION] = TUIBARRAGEIM_DATA_VERSION;
    result[TUIBARRAGEIM_SIGNALING_KEY_PLATFORM] = TUIBARRAGEIM_DATA_PLATFORM;
    result[TUIBARRAGEIM_SIGNALING_KEY_BUSINESSID] = TUIBARRAGEIM_DATA_BARRAGE;
    return result;
}

#pragma mark V2TIMSimpleMsgListener
/// 收到群自定义（信令）消息
- (void)onRecvGroupCustomMessage:(NSString *)msgID groupID:(NSString *)groupID sender:(V2TIMGroupMemberInfo *)info customData:(NSData *)data {
    if ([self.groupID isEqualToString:groupID] && data) {
        NSString* jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSDictionary* dic = [jsonString mj_JSONObject];
        NSDictionary *dicData = dic[TUIBARRAGEIM_SIGNALING_KEY_DATA];
        if (![dicData isKindOfClass:[NSDictionary class]] || !dicData.count) {
            return;
        }
        NSString *businessID = dic[TUIBARRAGEIM_SIGNALING_KEY_BUSINESSID];
        if (![businessID isKindOfClass:[NSString class]]) {
            return;
        }
        if ([businessID isEqualToString:TUIBARRAGEIM_DATA_BARRAGE]) {
            [self onReceive:dicData];
        }
    }
}

- (void)onRecvGroupTextMessage:(NSString *)msgID groupID:(NSString *)groupID sender:(V2TIMGroupMemberInfo *)info text:(NSString *)text {
    if ([self.groupID isEqualToString:groupID] && text.length > 0) {
        NSDictionary *dicData = @{@"message": text,
                                  @"extInfo": @{@"userID": (info.userID ?: @""),
                                                @"nickName": (info.nickName ?: @"")}
        };
        [self onReceive:dicData];
    }
}

@end
