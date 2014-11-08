//
//  HomeScene.m
//  NinjaRunner
//
//  Created by Nikola Bozhkov on 11/8/14.
//  Copyright (c) 2014 TeamOnaga. All rights reserved.
//

#import "HomeScene.h"
#import "GameScene.h"
#import "Util.h"

@implementation HomeScene

static NSString *playLabelName = @"Play";
static NSString *tutorialLabelName = @"Tutorial";
static NSString *leaderboardLabelName = @"Leaderboard";

- (void)didMoveToView:(SKView *)view {
    SKSpriteNode *background = [SKSpriteNode spriteNodeWithImageNamed:@"home_screen_background"];
    background.size = self.view.bounds.size;
    background.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    [self addChild:background];
    
    float labelMargin = self.frame.size.height * MarginPercent * 2;
    
    NSString *titleFont = @"Chalkduster";
    SKLabelNode *titleLabel = [Util createLabelWithFont:titleFont text:GameTitle fontColor:[SKColor whiteColor] fontSize:50];
    titleLabel.position = CGPointMake(self.frame.size.width / 2,
                                      self.frame.size.height - titleLabel.frame.size.height - labelMargin);
    [self addChild:titleLabel];
    
    SKLabelNode *playLabel = [Util createLabelWithFont:titleFont text:@"Play" fontColor:[SKColor whiteColor] fontSize:40];
    playLabel.name = playLabelName;
    playLabel.position = CGPointMake(self.frame.size.width - playLabel.frame.size.width / 2 - labelMargin,
                                     titleLabel.position.y - playLabel.frame.size.height - labelMargin);
    [self addChild:playLabel];
    
    SKLabelNode *tutorialLabel = [Util createLabelWithFont:titleFont text:@"Tutorial" fontColor:[SKColor whiteColor] fontSize:40];
    tutorialLabel.name = tutorialLabelName;
    tutorialLabel.position = CGPointMake(self.frame.size.width - tutorialLabel.frame.size.width / 2 - labelMargin,
                                         playLabel.position.y - tutorialLabel.frame.size.height - labelMargin * 2);
    [self addChild:tutorialLabel];
    
    SKLabelNode *leaderboardLabel = [Util createLabelWithFont:titleFont text:@"Leaderboard" fontColor:[SKColor whiteColor] fontSize:40];
    leaderboardLabel.name = leaderboardLabelName;
    leaderboardLabel.position = CGPointMake(self.frame.size.width - leaderboardLabel.frame.size.width / 2 - labelMargin,
                                            tutorialLabel.position.y - leaderboardLabel.frame.size.height - labelMargin * 2);
    [self addChild:leaderboardLabel];
    
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    SKNode *node = [self nodeAtPoint:location];
    
    SKTransition *transition = [SKTransition fadeWithDuration:1.0];
    
    if (node.name == playLabelName) {
        GameScene *gameScene = [GameScene sceneWithSize:self.frame.size];
        [self.view presentScene:gameScene transition:transition];
    } else if (node.name == tutorialLabelName) {
        
    } else if (node.name == leaderboardLabelName) {
        
    }
}

@end