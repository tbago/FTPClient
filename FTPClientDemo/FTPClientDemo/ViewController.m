//
//  ViewController.m
//  FTPClientDemo
//
//  Created by yuneec on 15/7/24.
//  Copyright (c) 2015年 tbago. All rights reserved.
//

#import "ViewController.h"
#import "FTPClient.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *FTPServerTextField;
@property (weak, nonatomic) IBOutlet UITextField *userNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UILabel    *statusLabel;

@property (strong, nonatomic) FTPClient         *ftpClient;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)uploadButtonClick:(UIButton *)sender {
    [self saveInputInfo];
    
    NSString *needUploadedFile = [self pathForTestResource:@"TestImage1.png"];
    
    self.ftpClient = [[FTPClient alloc] initWithFTPServer:self.FTPServerTextField.text
                                                       userName:self.userNameTextField.text
                                                       password:self.passwordTextField.text];
    __weak ViewController *weakSelf = self;
    
    [self.ftpClient uploadToFTPServer:needUploadedFile progress:^(NSInteger uploadedSize, NSInteger totalSize) {
        weakSelf.statusLabel.text = [NSString stringWithFormat:@"uploaded:%f%%", uploadedSize * 100.0 / totalSize];
    } completion:^(BOOL finished, NSString *messageString) {
        if (finished) {
            weakSelf.statusLabel.text = @"Success";
        }
        else {
            weakSelf.statusLabel.text = messageString;
        }
    }];
}


- (void)viewWillAppear:(BOOL)animated {
    NSUserDefaults *userDefaults    = [NSUserDefaults standardUserDefaults];
    self.FTPServerTextField.text    = [userDefaults objectForKey:@"FTPServer"];
    self.userNameTextField.text     = [userDefaults objectForKey:@"UserName"];
    self.passwordTextField.text     = [userDefaults objectForKey:@"Password"];
}

- (IBAction)backgroundTouchDown:(UITapGestureRecognizer *)sender {
    [self.view endEditing:YES];
}

#pragma mark - helper function

- (void)saveInputInfo
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:self.FTPServerTextField.text forKey:@"FTPServer"];
    [userDefaults setObject:self.userNameTextField.text forKey:@"UserName"];
    [userDefaults setObject:self.passwordTextField.text forKey:@"Password"];
    [userDefaults synchronize];
}

- (NSString *)pathForTestResource:(NSString *) resourceName
{
    NSUInteger          expansionFactor;
    NSString *          originalFilePath;
    NSString *          bigFilePath;
    NSFileManager *     fileManager;
    NSDictionary *      attrs;
    unsigned long long  originalFileSize;
    unsigned long long  bigFileSize;
    
    expansionFactor = 1;
    
    fileManager = [NSFileManager defaultManager];
    
    // Calculate paths to both the original file and the expanded file.
    
    originalFilePath = [[NSBundle mainBundle] pathForResource:[resourceName stringByDeletingPathExtension] ofType:[resourceName pathExtension]];
    assert(originalFilePath != nil);
    
    bigFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:resourceName];
    assert(bigFilePath != nil);
    
    // Get the sizes of each.
    
    attrs = [fileManager attributesOfItemAtPath:originalFilePath error:NULL];
    assert(attrs != nil);
    
    originalFileSize = [[attrs objectForKey:NSFileSize] unsignedLongLongValue];
    
    attrs = [fileManager attributesOfItemAtPath:bigFilePath error:NULL];
    if (attrs == NULL) {
        bigFileSize = 0;
    } else {
        bigFileSize = [[attrs objectForKey:NSFileSize] unsignedLongLongValue];
    }
    
    // If the expanded file is missing, or the wrong size, create it from scratch.
    
    if (bigFileSize != (originalFileSize * expansionFactor)) {
        NSOutputStream *    bigFileStream;
        NSData *            data;
        const uint8_t *     dataBuffer;
        NSUInteger          dataLength;
        NSUInteger          dataOffset;
        NSUInteger          counter;
        
        NSLog(@"%5zu - %@", (size_t) expansionFactor, bigFilePath);
        
        data = [NSData dataWithContentsOfMappedFile:originalFilePath];
        assert(data != nil);
        
        dataBuffer = [data bytes];
        dataLength = [data length];
        
        bigFileStream = [NSOutputStream outputStreamToFileAtPath:bigFilePath append:NO];
        assert(bigFileStream != NULL);
        
        [bigFileStream open];
        
        for (counter = 0; counter < expansionFactor; counter++) {
            dataOffset = 0;
            while (dataOffset != dataLength) {
                NSInteger       bytesWritten;
                
                bytesWritten = [bigFileStream write:&dataBuffer[dataOffset] maxLength:dataLength - dataOffset];
                assert(bytesWritten > 0);
                
                dataOffset += (NSUInteger) bytesWritten;
            }
        }
        
        [bigFileStream close];
    }
    
    return bigFilePath;
}
@end
