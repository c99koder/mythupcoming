//
//  MythTVStatus.m
//  mythstatus
//
//  Created by Sam Steele on 5/27/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MythTVStatus.h"
#import <sys/socket.h>
#import <netinet/in.h>

@implementation MythTVStatus
// This method lets you filter which methods in your plugin are accessible 
// to the JavaScript side.
+(BOOL)isSelectorExcludedFromWebScript:(SEL)aSel {	
	if (aSel == @selector(connect:port:protocol:) || aSel == @selector(disconnect) || aSel == @selector(getScheduledRecordings) || aSel == @selector(didFinishConnecting)) {
		return NO;
	}
	return YES;
}

// isKeyExcludedFromWebScript
//
// Prevents direct key access from JavaScript.
+(BOOL)isKeyExcludedFromWebScript:(const char*)k {
	return YES;
}

+(NSString*)webScriptNameForSelector:(SEL)aSel {
	NSString *retval = nil;
	
	if (aSel == @selector(connect:port:protocol:)) {
		retval = @"connect";
	} else if (aSel == @selector(getScheduledRecordings)) {
		retval = @"getScheduledRecordings";
	} else if (aSel == @selector(disconnect)) {
		retval = @"disconnect";
	} else if (aSel == @selector(didFinishConnecting)) {
		retval = @"didFinishConnecting";
	} else {
		NSLog(@"\tunknown selector");
	}
	
	return retval;
}

-(id)initWithWebView:(WebView*)w {
	self = [super init];
	return self;
}

-(void)windowScriptObjectAvailable:(WebScriptObject*)wso {
	[wso setValue:self forKey:@"MythTVStatusPlugin"];
}

- (id)initWithAddress:(NSString *)address port:(int)p
{
	self = [super init];
	
	[self connect:address port:p protocol:40];
	return self;
}

- (void)connect:(NSString *)address port:(int)p protocol:(int)proto {
	connected = false;
	mProto = proto;
	mPort = p;
	mAddress = [address copy];
	if(proto <= 30) {
		mProgInfoSize = 41;
	} else if(proto == 31) {
		mProgInfoSize = 42;
	} else if(proto <= 35) {
		mProgInfoSize = 43;
	} else if(proto > 35) {
		mProgInfoSize = 46;
	}
	
	CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,(CFStringRef)address,p,&rStream,&wStream);
	CFReadStreamSetProperty(rStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFReadStreamOpen(rStream);
	CFWriteStreamOpen(wStream);
	
	connected = [self didFinishConnecting];
}

- (BOOL)didFinishConnecting {
	if(connected == TRUE) {
		return TRUE;
	} else {
		if (CFWriteStreamCanAcceptBytes(wStream)) {
			[self sendCommand:[NSString stringWithFormat:@"MYTH_PROTO_VERSION %i", mProto]];
			NSArray *reply = [self readReply];
			if([[reply objectAtIndex:0] compare:@"ACCEPT"] == 0) {
				NSLog(@"Connected to backend using protocol version %@\n", [reply objectAtIndex:1]);
				[self sendCommand:[NSString stringWithFormat:@"ANN Monitor %@ 0", [[NSHost currentHost] name]]];
				if([[[self readReply] objectAtIndex:0] compare:@"OK"] == 0) {
					connected = TRUE;
					return TRUE;
				} else {
					NSLog(@"Announce failed\n");
				}
			} else {
				NSLog(@"Backend wants protocol version %@\n", [reply objectAtIndex:1]);
				[self disconnect];
				[self connect:mAddress port:mPort protocol:[[reply objectAtIndex:1] intValue]];
			}
		}
	}		
	return FALSE;
}

- (NSArray *)readReply {
	int bytes, size, offset=0;
	char buf[8];
	char *data;
	NSArray *result;
	bytes = CFReadStreamRead(rStream, buf, 8);
	if(bytes == 8) {
		buf[bytes] = '\0';
		size = atoi(buf);
		if(size > 0) {
			data = malloc(size);
			do {
				bytes = CFReadStreamRead(rStream, data + offset, size);
				offset += bytes;
				size -= bytes;
			} while(bytes < size);
				
			data[offset] = '\0';
			result = [[NSString stringWithCString:data] componentsSeparatedByString:@"[]:[]"];
			free(data);
			return result;
		}
	}
	return nil;
}

- (void)sendCommand:(NSString *)cmd {
	NSString *size = [[NSString stringWithFormat:@"%i", [cmd length]]  stringByPaddingToLength:8 withString: @" " startingAtIndex:0];
	NSString *buffer = [NSString stringWithFormat:@"%@%@", size, cmd];
	CFWriteStreamWrite(wStream, [buffer UTF8String], [buffer length]);
}

- (void)disconnect {
    [self sendCommand:@"DONE"];
	CFReadStreamClose(rStream);
	CFWriteStreamClose(wStream);
}

- (void)dealloc {
	[self disconnect];
    [super dealloc]; 
}

- (NSArray *)getScheduledRecordings {
	[self sendCommand:@"QUERY_GETALLPENDING"];
	NSArray *reply = [self readReply];
	int count = [reply count] / mProgInfoSize;
	NSMutableArray *recordings = nil;
	NSString *dateSuffix;
	int i=0;
	
	NSLog(@"Received %i recordings\n", count);
	
	if(count > 0) {
		recordings = [NSMutableArray arrayWithCapacity:count];
		
		for(i=0; i < count; i++) {
			if([[reply objectAtIndex:(i*mProgInfoSize + 23)] intValue] == rsWillRecord) {
				if([[[NSDate dateWithTimeIntervalSince1970:[[reply objectAtIndex:(i*mProgInfoSize + 13)] doubleValue]] descriptionWithCalendarFormat:@"%1d" timeZone:nil locale:nil] intValue] == 1) {
					dateSuffix = @"st";
				} else if([[[NSDate dateWithTimeIntervalSince1970:[[reply objectAtIndex:(i*mProgInfoSize + 13)] doubleValue]] descriptionWithCalendarFormat:@"%1d" timeZone:nil locale:nil] intValue] == 2) {
					dateSuffix = @"nd";
				} else if([[[NSDate dateWithTimeIntervalSince1970:[[reply objectAtIndex:(i*mProgInfoSize + 13)] doubleValue]] descriptionWithCalendarFormat:@"%1d" timeZone:nil locale:nil] intValue] == 3) {
					dateSuffix = @"rd";
				} else {
					dateSuffix = @"th";
				}
				[recordings addObject:[NSArray arrayWithObjects:
					[reply objectAtIndex:(i*mProgInfoSize + 2)],
					[reply objectAtIndex:(i*mProgInfoSize + 3)],
					[reply objectAtIndex:(i*mProgInfoSize + 4)],
					[reply objectAtIndex:(i*mProgInfoSize + 5)],
					[reply objectAtIndex:(i*mProgInfoSize + 7)],
					[reply objectAtIndex:(i*mProgInfoSize + 8)],
					[[[NSDate dateWithTimeIntervalSince1970:[[reply objectAtIndex:(i*mProgInfoSize + 13)] doubleValue]] descriptionWithCalendarFormat:@"%A, %B %1d" timeZone:nil locale:nil] stringByAppendingString:dateSuffix],
					[[NSDate dateWithTimeIntervalSince1970:[[reply objectAtIndex:(i*mProgInfoSize + 13)] doubleValue]] descriptionWithCalendarFormat:@"%1I:%M %p" timeZone:nil locale:nil],
					[reply objectAtIndex:(i*mProgInfoSize + 23)],
					nil			
				]];
			}
		}
	}
	[self sendCommand:@"OK"];
	return recordings;
}
@end