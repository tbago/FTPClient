//The MIT License (MIT)
//
//Copyright (c) 2015 tbago
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

#import "FTPClient.h"

typedef void (^ProcessBlock)(NSInteger uploadedSize, NSInteger totalSize);
typedef void (^CompleteBlock)(BOOL finished, NSString *messageString);

enum {
    kSendBufferSize = 32768
}; ///<everytime max transfer buffer size

@interface FTPClient() <NSStreamDelegate>

@property (strong, nonatomic) NSString      *currentStatus;
@property (strong, nonatomic) NSString      *FTPServer;
@property (strong, nonatomic) NSString      *userName;
@property (strong, nonatomic) NSString      *password;

@property (strong, nonatomic) NSOutputStream    *networkStream;
@property (strong, nonatomic) NSInputStream     *inputStream;
@property (nonatomic)         NSInteger         inputFileSize;

@property (readwrite, nonatomic, copy) ProcessBlock      processBlock;
@property (readwrite, nonatomic, copy) CompleteBlock     completeBlock;

@property (nonatomic, assign, readonly)  uint8_t            *buffer;
@property (nonatomic, assign, readwrite) NSInteger          bufferOffset;
@property (nonatomic, assign, readwrite) NSInteger          bufferLimit;

@end

@implementation FTPClient
{
    uint8_t                     _buffer[kSendBufferSize];
}

- (instancetype)initWithFTPServer:(NSString *) FTPServer
                         userName:(NSString *) userName
                         password:(NSString *) password {
    self = [super init];
    if (self) {
        self.FTPServer  = FTPServer;
        self.userName   = userName;
        self.password   = password;
    }
    return self;
}

- (void)uploadToFTPServer:(NSString *) uploadFilePath
                 progress:(void (^)(NSInteger uploadedSize, NSInteger totalSize)) progress
               completion:(void (^)(BOOL finished, NSString *messageString)) completion
{
    [self closeInputStream];
    
    self.processBlock = progress;
    self.completeBlock = completion;
    
    // Open a stream for the file we're going to send.  We do not open this stream;
    // NSURLConnection will do it for us.
    self.inputStream = [NSInputStream inputStreamWithFileAtPath:uploadFilePath];
    assert(self.inputStream != nil);
    [self.inputStream open];
    
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:uploadFilePath error:NULL];
    self.inputFileSize = [fileAttributes fileSize];
    
    self.networkStream = [self createOutputStream:uploadFilePath];
    [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.networkStream open];
}

#pragma mark - NSStreamDelegate
// An NSStream delegate callback that's called when events happen on our
// network stream.
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
#pragma unused(aStream)
    switch (eventCode)
    {
        case NSStreamEventOpenCompleted: {
            self.currentStatus = @"Opened connection";
        } break;
        case NSStreamEventHasBytesAvailable: {
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventHasSpaceAvailable: {
            self.currentStatus = @"Sending";
            
            // If we don't have any data buffered, go read the next chunk of data.
            if (self.bufferOffset == self.bufferLimit) {
                NSInteger   bytesRead = 0;
                bytesRead = [self.inputStream read:self.buffer maxLength:kSendBufferSize];
                
                if (bytesRead == -1) {
                    [self stopSendToFTPServer:@"File read error"];
                } else if (bytesRead == 0) {
                    [self stopSendToFTPServer:nil];     ///<success
                } else {
                    self.bufferOffset = 0;
                    self.bufferLimit  = bytesRead;
                }
            }
            
            // If we're not out of data completely, send the next chunk.
            if (self.bufferOffset != self.bufferLimit) {
                NSInteger   bytesWritten;
                bytesWritten = [self.networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                assert(bytesWritten != 0);
                if (bytesWritten == -1) {
                    [self stopSendToFTPServer:@"Network write error"];
                } else {
                    self.bufferOffset += bytesWritten;
                }
                self.processBlock([[self.inputStream propertyForKey:NSStreamFileCurrentOffsetKey] integerValue], self.inputFileSize);
            }
        } break;
        case NSStreamEventErrorOccurred: {
            [self stopSendToFTPServer:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
        } break;
        default: {
            assert(NO);
        } break;
    }
}

#pragma mark - private function

- (void)stopSendToFTPServer:(NSString *) statusString {
    if (self.networkStream) {
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.networkStream.delegate = nil;
        [self.networkStream close];
        self.networkStream = nil;
    }
    [self closeInputStream];
    
    BOOL completed = NO;
    if (statusString == nil) {
        statusString = @"Put succeeded";
        completed = YES;
    }
    
    self.currentStatus = statusString;
    self.completeBlock(completed, self.currentStatus);
}

- (void)closeInputStream {
    if (self.inputStream != nil) {
        [self.inputStream close];
        self.inputStream = nil;
    }
}

#pragma mark - get & set
- (NSOutputStream *)createOutputStream:(NSString *) inputFilePath
{
    NSURL *url = [self smartURLForString:self.FTPServer];
    if (url != nil) {
        // Add the last part of the file name to the end of the URL to form the final
        // URL that we're going to put to.
        url =  CFBridgingRelease(CFURLCreateCopyAppendingPathComponent(NULL, (__bridge CFURLRef) url, (__bridge CFStringRef) [inputFilePath lastPathComponent], false));

        NSOutputStream *networkStream = CFBridgingRelease(CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url));
        BOOL success = [networkStream setProperty:self.userName forKey:(id)kCFStreamPropertyFTPUserName];
        assert(success);
        success = [networkStream setProperty:self.password forKey:(id)kCFStreamPropertyFTPPassword];
        assert(success);
        networkStream.delegate = self;
        return networkStream;
    }
    return nil;
}

// Because buffer is declared as an array, you have to use a custom getter.
// A synthesised getter doesn't compile.
- (uint8_t *)buffer
{
    return self->_buffer;
}

#pragma mark - helper function

- (NSURL *)smartURLForString:(NSString *) stringUrl
{
    NSURL *result = nil;
    
    NSString *trimmedString = [stringUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ( (trimmedString != nil) && ([trimmedString length] != 0) ) {
        NSRange schemeMarkerRange = [trimmedString rangeOfString:@"://"];
        
        if (schemeMarkerRange.location == NSNotFound) {
            result = [NSURL URLWithString:[NSString stringWithFormat:@"ftp://%@", trimmedString]];
        } else {
            NSString * scheme = [trimmedString substringWithRange:NSMakeRange(0, schemeMarkerRange.location)];
            
            if ( ([scheme compare:@"ftp"  options:NSCaseInsensitiveSearch] == NSOrderedSame) ) {
                result = [NSURL URLWithString:trimmedString];
            } else {
                // It looks like this is some unsupported URL scheme.
            }
        }
    }
    
    return result;
}
@end
