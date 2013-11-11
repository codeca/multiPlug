//
//  Plug.m
//
//  Created by Guilherme Souza on 10/17/13.
//

#import "MultiPlug.h"

#define MULTIPLUG_LOG(str) if (MULTIPLUG_DEBUG) NSLog(str)

@interface MultiPlug()

@property NSMutableData* readBuffer;
@property NSMutableData* writeBuffer;
@property NSInputStream* inputStream;
@property NSOutputStream* outputStream;
@property BOOL hasSpace;
@property BOOL halfOpen;

@end

@implementation Plug

+ (MultiPlug*)multiPlug {
	return [[MultiPlug alloc] init];
}

- (id)init {
	if (self = [super init]) {
		NSString* url = [MULTIPLUG_EXTERNAL_HOST stringByAppendingFormat:@"/multiPlug/get.php?key=%@&noCache=%d", [[NSBundle mainBundle] bundleIdentifier], arc4random()];
		MULTIPLUG_LOG([NSString stringWithFormat:@"Getting server ip in %@", url]);
		NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
		NSOperationQueue* queue = [NSOperationQueue currentQueue];
		[NSURLConnection sendAsynchronousRequest:req queue:queue completionHandler:^(NSURLResponse* _, NSData* data, NSError* error) {
			if (error) {
				[self closeWithError];
				MULTIPLUG_LOG(@"Error with the request, check your Internet connection");
				return;
			}
			
			NSString* ip = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			MULTIPLUG_LOG([NSString stringWithFormat:@"Got %@, connecting at port %d", ip, MULTIPLUG_PORT]);
			
			CFReadStreamRef readStream;
			CFWriteStreamRef writeStream;
			CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)ip, MULTIPLUG_PORT, &readStream, &writeStream);
			self.inputStream = (__bridge_transfer NSInputStream*)readStream;
			self.outputStream = (__bridge_transfer NSOutputStream*)writeStream;
			
			[self.inputStream setDelegate:self];
			[self.outputStream setDelegate:self];
			[self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
			[self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
			[self.inputStream open];
			[self.outputStream open];
			
			self.writeBuffer = [[NSMutableData alloc] initWithCapacity:1024];
			self.readBuffer = [[NSMutableData alloc] initWithCapacity:1024];
		}];
	}
	return self;
}

- (void)sendMessage:(PlugMsgType)type data:(id)data {
	NSError* error = NULL;
	NSArray* message = @[[NSNumber numberWithInt:type], data];
	NSData* bufferData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
	int len = bufferData.length;
	uint8_t bytes[3];
	bytes[0] = len>>16;
	bytes[1] = (len>>8)%256;
	bytes[2] = len%256;
	NSData* lenBuffer = [[NSData alloc] initWithBytes:bytes length:3];
	[self.writeBuffer appendData:lenBuffer];
	[self.writeBuffer appendData:bufferData];
	if (self.hasSpace)
		[self write];
}

- (void)close {
	if (self.state != MULTIPLUGSTATE_CLOSED) {
		[self.inputStream close];
		[self.outputStream close];
		self.state = MULTIPLUGSTATE_CLOSED;
	}
}

#pragma mark - internal methods

// Listen to stream events
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	if (eventCode & NSStreamEventOpenCompleted) {
		// Stream opened
		if (self.halfOpen) {
			// Connected
			self.halfOpen = NO;
			self.state = MULTIPLUGSTATE_OPEN;
			[self.delegate multiPlugConnected:self];
		} else
			// Wait for both streams to open
			self.halfOpen = YES;
	} else if (eventCode & NSStreamEventEndEncountered || eventCode & NSStreamEventErrorOccurred) {
		// Stream closed
		self.state = MULTIPLUGSTATE_CLOSED;
		// TODO
		[self.delegate plug:self hasClosedWithError:!!(eventCode & NSStreamEventErrorOccurred)];
	} else if (aStream == self.outputStream && eventCode & NSStreamEventHasSpaceAvailable) {
		// The client can send more data
		if (self.writeBuffer.length)
			[self write];
		else
			self.hasSpace = YES;
	} else if (aStream == self.inputStream && eventCode & NSStreamEventHasBytesAvailable) {
		// Data has arrived
		[self read];
	}
}

// Try to send the cached write buffer
- (void)write {
	int len = self.writeBuffer.length;
	
	if (self.state == MULTIPLUGSTATE_CLOSED)
		return;
	
	int writtenLen = [self.outputStream write:self.writeBuffer.bytes maxLength:len];
	
	if (writtenLen == -1) {
		[self closeWithError];
		return;
	}
	
	if (writtenLen)
		[self.writeBuffer setData:[self.writeBuffer subdataWithRange:NSMakeRange(writtenLen, len-writtenLen)]];
	
	if (writtenLen != len)
		self.hasSpace = NO;
}

// Try to read all data from the stream
- (void)read {
	static uint8_t buffer[512];
	int readLen;
	
	if (self.state == MULTIPLUGSTATE_CLOSED)
		return;
	
	do {
		readLen = [self.inputStream read:buffer maxLength:512];
		if (readLen > 0)
			[self.readBuffer appendBytes:buffer length:readLen];
	} while (readLen == 512);
	
	if (readLen < 0) {
		[self closeWithError];
		return;
	}
	
	[self processMessages];
}

// Extract messages from the read data
- (void)processMessages {
	int len;
	uint8_t bytes[3];
	NSError* error = NULL;
	
	while (true) {
		if (self.readyState != PLUGSTATE_OPEN)
			return;
		
		// Read the message byte length
		if (self.readBuffer.length < 3)
			return;
		[self.readBuffer getBytes:bytes length:3];
		len = bytes[2]+(bytes[1]<<8)+(bytes[0]<<16);
		
		// Extract the data
		if (self.readBuffer.length < 3+len)
			return;
		NSData* data = [self.readBuffer subdataWithRange:NSMakeRange(3, len)];
		[self.readBuffer setData:[self.readBuffer subdataWithRange:NSMakeRange(len+3, self.readBuffer.length-len-3)]];
		
		// Inflate the JSON for [type data]
		NSArray* msg = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		if (error) {
			[self closeWithError];
			return;
		}
		NSNumber* type = msg[0];
		[self.delegate plug:self receivedMessage:[type intValue] data:msg[1]];
	}
}

// Close the current connection sending the error flag
- (void)closeWithError {
	self.state = MULTIPLUGSTATE_CLOSED;
	[self.delegate multiPlugClosedWithError:self];
}

@end
