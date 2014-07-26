//
//  UIScrollView+Blowing.m
//  BlowScrollView
//
//  Created by Tu You on 14-7-26.
//  Copyright (c) 2014年 Tu You. All rights reserved.
//

#import "UIScrollView+Blowing.h"
#import <AVFoundation/AVFoundation.h>
#import "objc/runtime.h"

#define kBlowThreshold   (0.80)

static char levelDetatorTimerKey;
static char recorderKey;
static char lowPassResultsKey;

@implementation UIScrollView (Blowing)

- (void)enableBlowToScroll
{
    NSURL *url = [NSURL fileURLWithPath:@"/dev/null"];
    
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithFloat: 44100.0], AVSampleRateKey,
                              [NSNumber numberWithInt: kAudioFormatAppleLossless], AVFormatIDKey,
                              [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
                              [NSNumber numberWithInt: AVAudioQualityMax], AVEncoderAudioQualityKey,
                              nil];
    
    NSError *error;
    
    AVAudioRecorder *recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];
    
    if (recorder) {
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        [audioSession setActive:YES error:nil];
        
        [recorder prepareToRecord];
        recorder.meteringEnabled = YES;
        [recorder record];
        
        objc_setAssociatedObject(self, &recorderKey, recorder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        NSTimer *levelDetactTimer = [NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(levelTimerCallback:) userInfo:nil repeats:YES];
        objc_setAssociatedObject(self, &levelDetatorTimerKey, levelDetactTimer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        NSNumber *lowPassResults = [NSNumber numberWithDouble:0.0f];
        objc_setAssociatedObject(self, &lowPassResultsKey, lowPassResults, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
}

- (void)levelTimerCallback:(NSTimer *)timer
{
    AVAudioRecorder *recorder = objc_getAssociatedObject(self, &recorderKey);
    [recorder updateMeters];
    
    double lowPassResults = [objc_getAssociatedObject(self, &lowPassResultsKey) doubleValue];
    
    const double ALPHA = 0.05;
    double peakPowerForChannel = pow(10, (0.05 * [recorder peakPowerForChannel:0]));
    lowPassResults = ALPHA * peakPowerForChannel + (1.0 - ALPHA) * lowPassResults;
    
    NSNumber *newLowPassResults = [NSNumber numberWithDouble:lowPassResults];
    objc_setAssociatedObject(self, &lowPassResultsKey, newLowPassResults, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    static BOOL animating = NO;
    if (lowPassResults > kBlowThreshold) {
        if (animating) {
            return;
        }
        
        double offset = lowPassResults * 160;
        animating = YES;
        // TODO: set contentoffset based on the moving direction of the scroll view & simulate the animation of scroll view using 
        [UIView animateWithDuration:0.75 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            CGPoint currentContentOffset = self.contentOffset;
            currentContentOffset.y += offset;
            [self setContentOffset:currentContentOffset];
        } completion:^(BOOL finished){
            animating = NO;
        }];
    }
}


@end
