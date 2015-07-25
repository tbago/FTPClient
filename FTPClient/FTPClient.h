//
//  FTPClient.h
//  FTPClientDemo
//
//  Created by yuneec on 15/7/24.
//  Copyright (c) 2015年 tbago. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FTPClient : NSObject

- (instancetype)initWithFTPServer:(NSString *) FTPServer
                         userName:(NSString *) userName
                         password:(NSString *) password NS_DESIGNATED_INITIALIZER;

- (void)uploadToFTPServer:(NSString *) uploadFilePath
                 progress:(void (^)(NSInteger uploadedSize, NSInteger totalSize)) progress
               completion:(void (^)(BOOL finished, NSString *messageString)) completion;
@end
