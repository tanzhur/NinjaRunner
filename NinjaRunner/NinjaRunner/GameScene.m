//
//  GameScene.m
//  NinjaRunner
//
//  Created by Nikola Bozhkov on 11/3/14.
//  Copyright (c) 2014 TeamOnaga. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <CoreData/CoreData.h>
#import "GameScene.h"
#import "NinjaNode.h"
#import "DragonNode.h"
#import "Util.h"
#import "BackgroundNode.h"
#import "GroundNode.h"
#import "ProjectileNode.h"
#import "ChargingNode.h"
#import "MonsterBullNode.h"
#import "EnemyFactory.h"
#import "HudNode.h"
#import "HomeScene.h"
#import "GameOverNode.h"
#import "CoreDataHelper.h"
#import "CDProfileDetails.h"
#import "LeaderboardScene.h"

@interface GameScene ()<SKPhysicsContactDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, assign) NSTimeInterval lastUpdateTimeInterval;
@property (nonatomic, assign) NSTimeInterval timeSinceLastUpdate;
@property (nonatomic, assign) NSTimeInterval timeSinceEnemyAdded;
@property (nonatomic, assign) NSTimeInterval totalGameTime;

@property (nonatomic, assign) BOOL gameOver;

@property (nonatomic, assign) NSTimeInterval longPressDuration;
@property (nonatomic, assign) BOOL isLongPressActive;

@property (nonatomic, assign) BOOL isPlayingMusic;
@property (nonatomic, strong) AVAudioPlayer *backgroundMusic;
@property (nonatomic, strong) AVAudioPlayer *gameOverMusic;

@end

@implementation GameScene {
    UISwipeGestureRecognizer *swipeUpRecognizer;
    UISwipeGestureRecognizer *swipeRightRecognizer;
    UILongPressGestureRecognizer *longPressRecognizer;
    UITapGestureRecognizer *tapRecognizer;
    
    BackgroundNode *background;
    NinjaNode *ninja;
    ChargingNode *chargingNode;
    HudNode *hud;
    
    CDProfileDetails *playerScore;
    
    SKSpriteNode *quitButton;
    SKSpriteNode *rerunButton;
    
    SKLabelNode *pauseLabel;
    
    NSString *bloodParticlesFilePath;
}

- (void) didMoveToView:(SKView *)view {
    /* Setup your scene here */
    
    self.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
    _timeSinceEnemyAdded = 0;
    _totalGameTime = 0;
    _gameOver = NO;
    _isPlayingMusic = NO;
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(handlePause)
     name:UIApplicationWillResignActiveNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(handleUnpause)
     name:UIApplicationDidBecomeActiveNotification
     object:nil];
    
    bloodParticlesFilePath = [[NSBundle mainBundle] pathForResource:@"BloodParticles" ofType:@"sks"];
    [self setupGestureRecognizers];
    
    CGFloat sceneGravity = -self.frame.size.height * GravityMultiplier; // ~8
    self.physicsWorld.gravity = CGVectorMake(0, sceneGravity);
    self.physicsWorld.contactDelegate = self;
    
    background = [BackgroundNode backgroundAtPosition:CGPointZero parent:self];
    [self addChild:background];
    
    SKSpriteNode *backgroundImage = (SKSpriteNode *)[background childNodeWithName:BackgroundSpriteName];
    _groundHeight = backgroundImage.size.height * BackgroundLandHeightPercent;
    
    hud = [HudNode hudAtPosition:CGPointMake(0, self.frame.size.height - 20) withFrame:self.frame];
    [self addChild:hud];
    
    pauseLabel = [Util createLabelWithFont:@"Futura-CondensedExtraBold" text:@"Paused" fontColor:[SKColor orangeColor] fontSize:40];
    pauseLabel.zPosition = 10;
    pauseLabel.position = _center;
    
    GroundNode *ground = [GroundNode groundWithSize:CGSizeMake(self.frame.size.width, _groundHeight)];
    [self addChild:ground];
    
    CGFloat ninjaPositionX = self.frame.size.width * NinjaPositionXPercent;
    ninja = [NinjaNode ninjaWithPosition:CGPointMake(ninjaPositionX, _groundHeight) inScene:self];
    [self addChild:ninja];

    [self setupSounds];
    [_backgroundMusic play];
    
    _isPlayingMusic = YES;
}

- (void) setupGestureRecognizers {
    swipeUpRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeUpRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:swipeUpRecognizer];
    
    swipeRightRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeRightRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRightRecognizer];
    
    longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPressRecognizer.minimumPressDuration = 0.25;
    [self.view addGestureRecognizer:longPressRecognizer];
    
    tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTouch:)];
    tapRecognizer.numberOfTouchesRequired = 2;
    [self.view addGestureRecognizer:tapRecognizer];
}

- (void) handleSwipe:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.direction == UISwipeGestureRecognizerDirectionUp) {
        [ninja jump];
    } else if (recognizer.direction == UISwipeGestureRecognizerDirectionRight) {
        [ninja attack];
    }
}

- (void) handleLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        chargingNode = [ChargingNode chargingNodeWithPosition:self.center text:ChargingLabelText];
        [self addChild:chargingNode];
        _isLongPressActive = YES;
    }
    
    if (recognizer.state == UIGestureRecognizerStateCancelled) {
        _isLongPressActive = NO;
        _longPressDuration = 0;
        [chargingNode finishChargingWithText:ChargedLabelText];
        [ninja chargeAttack];
    }
    
    if (recognizer.state == UIGestureRecognizerStateEnded
        || recognizer.state == UIGestureRecognizerStateFailed) {
        _isLongPressActive = NO;
        _longPressDuration = 0;
        [chargingNode removeFromParent];
    }
}

- (void) handleDoubleTouch:(UITapGestureRecognizer *)recognizer {
    NSString *text;
    if (!ninja.powerAttackUsedAfterCd) {
        [ninja enablePowerAttack];
        text = PowerAttackText;
    } else {
        NSTimeInterval cooldownLeft = ninja.powerAttackCooldown - ninja.lastPowerAttackAgo;
        text = [NSString stringWithFormat:@"%@ %.02fsec", PowerAttackOnCdText, cooldownLeft];
    }
    
    ChargingNode *powerAttackCharge = [ChargingNode chargingNodeWithPosition:self.center text:text];
    [self addChild:powerAttackCharge];
    [powerAttackCharge finishChargingWithText:text];
}

- (void) handlePause {
    [self addChild:pauseLabel];
    [_backgroundMusic pause];
}

- (void) handleUnpause {
    self.paused = YES;
    [_backgroundMusic play];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    SKNode *node = [self nodeAtPoint:location];
    
    if ([node isEqual:hud.pauseButton]) {
        if (self.paused) {
            self.paused = NO;
            _lastUpdateTimeInterval = 0;
            [pauseLabel removeFromParent];
            [_backgroundMusic play];
        } else {
            [self addChild:pauseLabel];
            self.paused = YES;
            [_backgroundMusic pause];
        }
    }
    
    if ([node.name isEqualToString:@"musicButton"]) {
        if (_isPlayingMusic) {
            [_backgroundMusic stop];
            _isPlayingMusic = NO;
        } else {
            [_backgroundMusic play];
            _isPlayingMusic = YES;
        }
    }
    
    if ([node.name isEqualToString: ReplayLabelName]) {
        GameScene *scene = [GameScene sceneWithSize:self.frame.size];
        [self.view presentScene:scene];
    } else if ([node.name isEqualToString: MenuLabelName]) {
        HomeScene *home = [HomeScene sceneWithSize:self.frame.size];
        SKTransition *transition = [SKTransition fadeWithDuration:1.0];
        [self.view presentScene:home transition:transition];
    } else if ([node.name isEqualToString:LeaderboardLabelName]) {
        LeaderboardScene *leaderboardScene = [LeaderboardScene sceneWithSize:self.frame.size];
        SKTransition *transition = [SKTransition fadeWithDuration:1];
        [self.view presentScene:leaderboardScene transition:transition];
    }
}

- (void) didBeginContact:(SKPhysicsContact *)contact {
    SKPhysicsBody *firstBody, *secondBody;
    
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask) {
        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
    } else {
        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
    }
    
    if (firstBody.categoryBitMask == CollisionCategoryEnemy
        && secondBody.categoryBitMask == CollisionCategoryNinja) {
        if (!_gameOver) {
            [self endGame];
        }
        _gameOver = YES;
        [_backgroundMusic stop];
        [_gameOverMusic play];
    }

    // Reset jumps count on ground touch
    if (firstBody.categoryBitMask == CollisionCategoryNinja
        && secondBody.categoryBitMask == CollisionCategoryGround) {
        ninja.jumpsInProgressCount = 0;
        [ninja removeActionForKey:NinjaJumpActionKey];
    }
    
    if (firstBody.categoryBitMask == CollisionCategoryEnemy
        && secondBody.categoryBitMask == CollisionCategoryProjectile) {
        EnemyNode *enemy = (EnemyNode *)firstBody.node;
        ProjectileNode *projectile = (ProjectileNode *)secondBody.node;
        
        enemy.health -= projectile.damage;
        
        if (enemy.health <= 0) {
            [enemy removeFromParent];
            [hud addPoints:enemy.pointsForKill];
            hud.kills++;
        }
        
        if (projectile.chargedEmitter != nil) {
            [projectile.chargedEmitter removeFromParent];
        }
        
        SKEmitterNode *bloodParticles = [NSKeyedUnarchiver unarchiveObjectWithFile:bloodParticlesFilePath];
        bloodParticles.position = enemy.position;
        bloodParticles.zPosition = -1;
        [self addChild:bloodParticles];
        
        [projectile removeFromParent];
    }
}

- (void) chargeLongPress {
    _longPressDuration += _timeSinceLastUpdate;
    
    if (_longPressDuration >= ChargeAttackDuration) {
        // Interrupt the long press(it is completed)
        longPressRecognizer.enabled = NO;
        longPressRecognizer.enabled = YES;
    }
}

- (void) addEnemy {
    EnemyType enemyType = (EnemyType)arc4random_uniform(2);
    EnemyNode *enemy = [EnemyFactory createEnemyWithType:enemyType inScene:self];
    [EnemyFactory createDragonByChance:DragonSpawnChance inScene:self];
    
    [self addChild:enemy];
}

- (void) setupSounds {
    NSURL *backgroundMusicUrl = [[NSBundle mainBundle] URLForResource:@"BackgroundMusic" withExtension:@".mp3"];
    
    self.backgroundMusic = [[AVAudioPlayer alloc] initWithContentsOfURL:backgroundMusicUrl error:nil];
    self.backgroundMusic.numberOfLoops = -1;
    [self.backgroundMusic prepareToPlay];
    
    NSURL *gameOverMusicUrl = [[NSBundle mainBundle] URLForResource:@"GameOver" withExtension:@".mp3"];
    
    self.gameOverMusic = [[AVAudioPlayer alloc] initWithContentsOfURL:gameOverMusicUrl error:nil];
    self.gameOverMusic.numberOfLoops = 1;
    [self.gameOverMusic prepareToPlay];
}

- (void) saveProfileDetails {
    Profile.highScore = Profile.highScore < hud.score ? hud.score : Profile.highScore;
    Profile.totalScore += hud.score;
    Profile.mostKills = Profile.mostKills < hud.kills ? hud.kills : Profile.mostKills;
    Profile.totalKills += hud.kills;
    Profile.longestGameTime = Profile.longestGameTime < _totalGameTime ? _totalGameTime : Profile.longestGameTime;
    Profile.totalGameTime += _totalGameTime;
    
    [Util saveProfileDetails:Profile];
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"CDPlayerDetails"];
    NSArray *fetchedObjects = [coreDataHelper.context executeFetchRequest:request error:nil];
    
    if (fetchedObjects.count == 0) {
        playerScore = [NSEntityDescription insertNewObjectForEntityForName:@"CDPlayerDetails"
                                                    inManagedObjectContext:coreDataHelper.context];
    } else {
        playerScore = fetchedObjects.firstObject;
    }
    
    playerScore.highScore = [NSNumber numberWithInteger:Profile.highScore];
    playerScore.totalScore = [NSNumber numberWithInteger:Profile.totalScore];
    playerScore.mostKills = [NSNumber numberWithInteger:Profile.mostKills];
    playerScore.totalKills = [NSNumber numberWithInteger:Profile.totalKills];
    playerScore.longestGame = [NSNumber numberWithDouble:Profile.longestGameTime];
    playerScore.totalGameTime = [NSNumber numberWithDouble:Profile.totalGameTime];
    [coreDataHelper saveContext];
}

- (void) endGame {
    [self.view removeGestureRecognizer:tapRecognizer];
    [self.view removeGestureRecognizer:longPressRecognizer];
    [self.view removeGestureRecognizer:swipeUpRecognizer];
    [self.view removeGestureRecognizer:swipeRightRecognizer];
    
    background.velocity = CGPointMake(0, 0);
    [ninja die];
    
    [hud runAction:[SKAction fadeOutWithDuration:0.7]];
    
    GameOverNode *gameOver = [GameOverNode gameOverAtPosition:CGPointZero score:hud.score kills:hud.kills scene:self];
    [self addChild:gameOver];
    
    [self saveProfileDetails];
}

-(void) update:(CFTimeInterval)currentTime {
    if (self.paused) {
        return;
    }
    
    if (_lastUpdateTimeInterval) {
        _timeSinceLastUpdate = currentTime - _lastUpdateTimeInterval;
        _timeSinceEnemyAdded += _timeSinceLastUpdate;
    }
    
    if (!_gameOver) {
        _totalGameTime += _timeSinceLastUpdate;
    }
    
    if (_timeSinceEnemyAdded > EnemySpawnTimeInterval && !_gameOver) {
        [self addEnemy];
        _timeSinceEnemyAdded = 0;
    }
    
    if (ninja.powerAttackUsedAfterCd) {
        ninja.lastPowerAttackAgo += _timeSinceLastUpdate;
        
        if (ninja.lastPowerAttackAgo > ninja.powerAttackCooldown) {
            ninja.powerAttackUsedAfterCd = NO;
            ninja.lastPowerAttackAgo = 0;
        }
    }
    
    if (_isLongPressActive) {
        [self chargeLongPress];
    }
    
    [background moveByTimeSinceLastUpdate:_timeSinceLastUpdate];
    
    self.lastUpdateTimeInterval = currentTime;
}

@end
