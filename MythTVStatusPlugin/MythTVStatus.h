//
//  MythTVStatus.h
//  mythstatus
//
//  Created by Sam Steele on 5/27/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

enum RecStatusType {
    rsFailed = -9,
    rsTunerBusy = -8,
    rsLowDiskSpace = -7,
    rsCancelled = -6,
    rsMissed = -5,
    rsAborted = -4,
    rsRecorded = -3,
    rsRecording = -2,
    rsWillRecord = -1,
    rsUnknown = 0,
    rsDontRecord = 1,
    rsPreviousRecording = 2,
    rsCurrentRecording = 3,
    rsEarlierShowing = 4,
    rsTooManyRecordings = 5,
    rsNotListed = 6,
    rsConflict = 7,
    rsLaterShowing = 8,
    rsRepeat = 9,
    rsInactive = 10,
    rsNeverRecord = 11,
    rsOffLine = 12,
    rsOtherShowing = 13
};

@interface MythTVStatus : NSObject {
  CFReadStreamRef rStream;
  CFWriteStreamRef wStream;
	BOOL connected;
	int mProto,mPort,mProgInfoSize;
	NSString *mAddress;
}

- (id)initWithAddress:(NSString *)address port:(int)p;
- (void)connect:(NSString *)address port:(int)p protocol:(int)proto;
- (BOOL)didFinishConnecting;
- (void)sendCommand:(NSString *)cmd;
- (NSArray *)readReply;
- (void)disconnect;
- (void)dealloc;
- (NSArray *)getScheduledRecordings;
@end

Boolean WaitForConnection(CFWriteStreamRef wStream);

@interface MyPluginClass : NSObject {
	short sayingCount;
}

@end
