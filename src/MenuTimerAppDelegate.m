//
//  MenuTimerAppDelegate.m
//  MenuTimer
//
//  Created by Kristopher Johnson on 3/19/09.
//  Copyright 2009 Capable Hands Technologies, Inc.. All rights reserved.
//
//  This file is part of Menubar Countdown.
//
//  Menubar Countdown is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Menubar Countdown is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Menubar Countdown.  If not, see <http://www.gnu.org/licenses/>.
//

#import "MenuTimerAppDelegate.h"
#import "Stopwatch.h"


@interface MenuTimerAppDelegate (private)
- (void)nextSecondTimerDidFire:(NSTimer*)timer;
- (void)updateStatusItemTitle:(int)timeRemaining;
- (void)timerDidExpire;
- (NSString *)timeToString:(int)time;
- (int)stringToTime:(NSString *)timeString;
@end


@implementation MenuTimerAppDelegate

@synthesize timerIsRunning;
@synthesize canResume;


- (void)dealloc {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];

    [stopwatch release];
    [statusItem release];
    [menu release];
    [super dealloc];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    timerSettingSeconds = 25 * 60;
    secondsRemaining = timerSettingSeconds;
    self.timerIsRunning = NO;

    [stopwatch reset];

    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem retain];
    [self updateStatusItemTitle:0];
    [statusItem setMenu:menu];
    [statusItem setHighlightMode:YES];
    [statusItem setToolTip:NSLocalizedString(@"Menubar Countdown",
                                             @"Status Item Tooltip")];
}


- (void)updateStatusItemTitle:(int)timeRemaining {
    [statusItem setTitle:[self timeToString:timeRemaining]];
}

- (NSString *)timeToString:(int)time {
    // TODO: can only handle up to 99 minutes
    int minutes = time / 60;
    int seconds = time % 60;
    
    NSString* timeString = [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];

    return timeString;
}

- (int)stringToTime:(NSString *)timeString {
    // TODO: fix hacky array indexing that relies on menu text
    
    NSArray *timeArray = [timeString componentsSeparatedByString:@":"];
    int minutes = [timeArray[0] intValue];
    int seconds = [timeArray[1] intValue];

    return (minutes * 60) + seconds;
}


- (void)waitForNextSecond {
    NSTimeInterval elapsed = [stopwatch elapsedTimeInterval];
    double intervalToNextSecond = ceil(elapsed) - elapsed;

    [NSTimer scheduledTimerWithTimeInterval:intervalToNextSecond
                                     target:self
                                   selector:@selector(nextSecondTimerDidFire:)
                                   userInfo:nil
                                    repeats:NO];
}


- (void)nextSecondTimerDidFire:(NSTimer*)timer {
    if (self.timerIsRunning) {
        secondsRemaining = nearbyint(timerSettingSeconds - [stopwatch elapsedTimeInterval]);
        if (secondsRemaining <= 0) {
            [self timerDidExpire];
        }
        else {
            [self updateStatusItemTitle:secondsRemaining];
            [self waitForNextSecond];
        }
    }
}


- (IBAction)startTimer:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem*)sender;
    
    timerSettingSeconds = [self stringToTime:[menuItem title]];
    self.timerIsRunning = YES;
    self.canResume = NO;
    [stopwatch reset];
    [self updateStatusItemTitle:timerSettingSeconds];
    [self waitForNextSecond];
}


- (IBAction)pauseTimer:(id)sender {
    self.timerIsRunning = NO;
    if (secondsRemaining > 0) {
        self.canResume = YES;
    }
}


- (IBAction)resumeTimer:(id)sender {
    if (secondsRemaining < 1) {
        return;
    }
    timerSettingSeconds = secondsRemaining;
    self.timerIsRunning = YES;
    self.canResume = NO;
    [stopwatch reset];
    [self updateStatusItemTitle:timerSettingSeconds];
    [self waitForNextSecond];
}


- (void)timerDidExpire {
    self.canResume = NO;
    self.timerIsRunning = NO;
    [self updateStatusItemTitle:0];

    NSUserNotification *notification = [[NSUserNotification alloc] init];
    [notification setTitle:@"MenuTimer"];
    [notification setInformativeText:@"Time's up!"];
    [notification setSoundName:NSUserNotificationDefaultSoundName];

    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

@end
