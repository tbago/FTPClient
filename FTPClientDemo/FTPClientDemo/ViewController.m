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

#import "ViewController.h"
#import "FTPClient.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *FTPServerTextField;
@property (weak, nonatomic) IBOutlet UITextField *userNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UILabel    *statusLabel;
@property (weak, nonatomic) IBOutlet UIButton   *cancelButton;

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
    
    NSString *needUploadedFile = [self pathForTestResource:@"TestImage1.bin"];
    
    self.ftpClient = [[FTPClient alloc] initWithFTPServer:self.FTPServerTextField.text
                                                       userName:self.userNameTextField.text
                                                       password:self.passwordTextField.text];
    __weak ViewController *weakSelf = self;
    
    self.cancelButton.enabled = YES;
    [self.ftpClient uploadToFTPServer:needUploadedFile progress:^(NSInteger uploadedSize, NSInteger totalSize) {
        weakSelf.statusLabel.text = [NSString stringWithFormat:@"uploaded:%f%%", uploadedSize * 100.0 / totalSize];
        NSLog(@"upload size:%ld", uploadedSize);
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
    self.cancelButton.enabled       = NO;
}

- (IBAction)backgroundTouchDown:(UITapGestureRecognizer *)sender {
    [self.view endEditing:YES];
}

- (IBAction)cancelButtonClick:(id)sender {
    [self.ftpClient canceled];
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
