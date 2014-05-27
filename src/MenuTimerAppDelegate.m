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
- (void)announceTimerExpired;
- (NSString*)announcementText;
- (void)removeOldIntervals:(NSArray*)oldIntervals renderNew:(NSArray*)newIntervals;
- (void)reallyStartTimer:(int)seconds;
- (NSString *)timeToString:(int)time showSeconds:(BOOL)showSeconds;
@end


@implementation MenuTimerAppDelegate

@synthesize timerIsRunning;
@synthesize canResume;


+ (void)initialize {
}


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
    
    
    // render the dynamic menu
    [self removeOldIntervals:nil 
                   renderNew:[[NSUserDefaults standardUserDefaults] arrayForKey:UserDefaultsRecentTimerIntervals]];
    [defaults addObserver:self
               forKeyPath:UserDefaultsRecentTimerIntervals
                  options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                  context:nil];

}

- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context {
    if ([keyPath isEqualToString:UserDefaultsRecentTimerIntervals]) {
        [self removeOldIntervals:[change objectForKey:@"old"]
                       renderNew:[change objectForKey:@"new"]];
    }
}

- (void)removeOldIntervals:(NSArray *)oldIntervals renderNew:(NSArray *)newIntervals {
    NSUInteger LOCATION_IDX = 4;
    for (int i = 0; i < [oldIntervals count]; i++)
    {
        [menu removeItemAtIndex:LOCATION_IDX];
    }
     
    NSUInteger idx = [newIntervals count];
    for (NSNumber *interval in [newIntervals reverseObjectEnumerator]) {
        idx--;
        NSMenuItem *mi = [menu insertItemWithTitle:[self timeToString:[interval intValue] showSeconds:true]
                                            action:@selector(onMenuShortcutClick:) 
                                     keyEquivalent:@"" 
                                           atIndex:LOCATION_IDX];
        [mi setTag:idx];
        [mi setTarget:self];
    }
}

- (void)onMenuShortcutClick:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *recentIntervals = [defaults arrayForKey:UserDefaultsRecentTimerIntervals];
    [self reallyStartTimer:[[recentIntervals objectAtIndex:[sender tag]] intValue]];
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
    if (!startTimerDialogController) {
        [NSBundle loadNibNamed:@"StartTimerDialog" owner:self];
    }
    [startTimerDialogController showDialog];
}


- (IBAction)startTimerDialogStartButtonWasClicked:(id)sender {

    [startTimerDialogController dismissDialog:sender];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults synchronize];

    int timerIntervalSecs = (int)[startTimerDialogController timerInterval];
    
    NSMutableArray *recentTimerIntervals = 
        [NSMutableArray arrayWithArray:[defaults arrayForKey:UserDefaultsRecentTimerIntervals]];
    NSUInteger MAX_INTERVALS = 5;
    [recentTimerIntervals insertObject:[NSNumber numberWithInteger:timerIntervalSecs] atIndex:0];
    if ([recentTimerIntervals count] > MAX_INTERVALS)
    {
        [recentTimerIntervals removeLastObject];
    }
    [defaults setObject:recentTimerIntervals forKey:UserDefaultsRecentTimerIntervals];
    
    [self reallyStartTimer:timerIntervalSecs];
    
}

- (void)reallyStartTimer:(int)seconds {
    timerSettingSeconds = seconds;
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
}


- (void)announceTimerExpired {
    NSSpeechSynthesizer *synth = [[NSSpeechSynthesizer alloc] initWithVoice:nil];
    [synth startSpeakingString:[self announcementText]];
    [synth release];
}


- (IBAction)restartCountdownWasClicked:(id)sender {
    [self startTimer:sender];
}


@end
