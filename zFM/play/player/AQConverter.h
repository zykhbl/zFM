//
//  AQConverter.h
//  zFM
//
//  Created by zykhbl on 15-9-25.
//  Copyright (c) 2015年 zykhbl. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AQConverter : NSObject

- (OSStatus)doConvertFile:(NSString*)url;

- (void)selectIpodEQPreset:(NSInteger)index;

@end
