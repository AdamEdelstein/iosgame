//
//  MyScene.m
//  SpaceShooter
//
//  Created by Tony Dahbura on 9/9/13.
//  Copyright (c) 2013 fullmoonmanor. All rights reserved.
//

@import AVFoundation;


#import "MyScene.h"
#import "FMMParallaxNode.h"

#import "KAZ_JoystickNode.h"

@interface MyScene(){
    SKNode *control;
    SKSpriteNode *sprite;
    UITouch *joystickTouch;
    CGPoint touchPoint;
    CGSize move;
    
    KAZ_JoystickNode *moveJoystick;
    KAZ_JoystickNode *shootJoystick;
    CFTimeInterval lastUpdate;
}

@end

// Add to top of file
#define kNumAsteroids   15
#define kNumLasers      5



typedef enum {
    kEndReasonWin,
    kEndReasonLose
} EndReason;

@implementation MyScene {
    SKNode *node;
    
    SKSpriteNode *_ship;
    FMMParallaxNode *_parallaxNodeBackgrounds;
    FMMParallaxNode *_parallaxSpaceDust;
    
    
    
    NSMutableArray *_asteroids;
    int _nextAsteroid;
    double _nextAsteroidSpawn;
    
    NSMutableArray *_shipLasers;
    int _nextShipLaser;
    
    int _lives;
    double _gameOverTime;
    bool _gameOver;
    
//    int score;
//    score = 0;
//    _score 0;
    
    AVAudioPlayer *_backgroundAudioPlayer;

    
}



// All three of the next are for joystick implementation

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInNode:self];
        
        
        //check if they touched your Restart Label
        for (UITouch *touch in touches) {
            SKNode *n = [self nodeAtPoint:[touch locationInNode:self]];
            if (n != self && [n.name isEqual: @"restartLabel"]) {
                [[self childNodeWithName:@"restartLabel"] removeFromParent];
                [[self childNodeWithName:@"winLoseLabel"] removeFromParent];
                [[self childNodeWithName:@"titleScreen"] removeFromParent];

                [self startTheGame];
                return;
            }
        }
        
        //do not process anymore touches since it's game over
        if (_gameOver) {
            return;
        }
        
        
        // If the user touches the left side of the screen, draw the joystick
        if ( location.x < self.size.width / 2 ){
            [moveJoystick startControlFromTouch:touch andLocation:location];
            
            // Else: the user must be touching the bottom right -> use the shotting joystick
            // Note: else is used for the shooting stick for the rest of the events
        } else {
            
            // [shootJoystick startControlFromTouch:touch andLocation:location];
            
            
            /* Called when a touch begins */
            //1 Pick up a laser from one of your pre-made lasers.
            SKSpriteNode *shipLaser = [_shipLasers objectAtIndex:_nextShipLaser];
            _nextShipLaser++;
            if (_nextShipLaser >= _shipLasers.count) {
                _nextShipLaser = 0;
            }
            
            //2 Set the initial position of the laser to where your ship is positioned.
            shipLaser.position = CGPointMake(_ship.position.x+shipLaser.size.width/2, _ship.position.y+0);
            shipLaser.hidden = NO;
            [shipLaser removeAllActions];
            
            //3 Set the end position off screen (X) and at the same Y position as it started.
            //  Define a move action to move to the edge of the screen from the initial position with a duration of a 1/2 second
            
            CGPoint location = CGPointMake(self.frame.size.width, _ship.position.y);
            SKAction *laserMoveAction = [SKAction moveTo:location duration:0.5];
            
            //4 Define a done action using a block that hides the laser when it hits the right edge.
            SKAction *laserDoneAction = [SKAction runBlock:(dispatch_block_t)^() {
                //NSLog(@"Animation Completed");
                shipLaser.hidden = YES;
            }];
            
            //5 Define a sequence action of the move and done actions
            SKAction *moveLaserActionWithDone = [SKAction sequence:@[laserMoveAction,laserDoneAction]];
            
            //6 Run the sequence on the laser sprite
            [shipLaser runAction:moveLaserActionWithDone withKey:@"laserFired"];
            
            
        }
    }
}

// matches the movement of the joystick to the ship
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    for (UITouch *touch in touches) {
        if ( touch == moveJoystick.startTouch){
            [moveJoystick moveControlToLocation:touch andLocation:[touch locationInNode:self]];
        } else if ( touch == shootJoystick.startTouch){
            [shootJoystick moveControlToLocation:touch andLocation:[touch locationInNode:self]];
        }
    }
}

// removes the joystick when the user removes the left thumb
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    for (UITouch *touch in touches) {
        if ( touch == moveJoystick.startTouch){
            [moveJoystick endControl];
        } else if ( touch == shootJoystick.startTouch){
            [shootJoystick endControl];
        }
    }
}


-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
        
        NSLog(@"SKScene:initWithSize %f x %f",size.width,size.height);
        
        self.backgroundColor = [SKColor blackColor];

        //Define our physics body around the screen - used by our ship to not bounce off the screen
        self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];

#pragma mark - Game Backgrounds
        NSArray *parallaxBackgroundNames = @[@"bg_galaxy.png", @"bg_planetsunrise.png",
                                             @"bg_spacialanomaly.png", @"bg_spacialanomaly2.png"];
        CGSize planetSizes = CGSizeMake(200.0, 200.0);
        _parallaxNodeBackgrounds = [[FMMParallaxNode alloc] initWithBackgrounds:parallaxBackgroundNames
                                                                              size:planetSizes
                                                              pointsPerSecondSpeed:10.0];
        _parallaxNodeBackgrounds.position = CGPointMake(size.width/2.0, size.height/2.0);
        [_parallaxNodeBackgrounds randomizeNodesPositions];
        [self addChild:_parallaxNodeBackgrounds];

        //Bring on the space dust
        NSArray *parallaxBackground2Names = @[@"bg_front_spacedust.png",@"bg_front_spacedust.png"];
        _parallaxSpaceDust = [[FMMParallaxNode alloc] initWithBackgrounds:parallaxBackground2Names
                                                                    size:size
                                                    pointsPerSecondSpeed:25.0];
        _parallaxSpaceDust.position = CGPointMake(0, 0);
        [self addChild:_parallaxSpaceDust];
            
#pragma mark - Setup Sprite for the ship
        //Create space sprite, setup position on left edge centered on the screen, and add to Scene
        _ship = [SKSpriteNode spriteNodeWithImageNamed:@"SpaceFlier_sm_1.png"];
        _ship.position = CGPointMake(self.frame.size.width * 0.1, CGRectGetMidY(self.frame));
        //move the ship using Sprite Kit's Physics Engine
        //Create a rectangular physics body the same size as the ship.
        _ship.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:_ship.frame.size];
        
        //Make the shape dynamic; this makes it subject to things such as collisions and other outside forces.
        _ship.physicsBody.dynamic = YES;
        
        //You don't want the ship to drop off the bottom of the screen, so you indicate that it's not affected by gravity.
        _ship.physicsBody.affectedByGravity = NO;
        
        //Give the ship an arbitrary mass so that its movement feels natural.
        _ship.physicsBody.mass = 0.02;

        [self addChild:_ship];
        
#pragma mark - Setup the asteroids
        _asteroids = [[NSMutableArray alloc] initWithCapacity:kNumAsteroids];
        for (int i = 0; i < kNumAsteroids; ++i) {
            SKSpriteNode *asteroid = [SKSpriteNode spriteNodeWithImageNamed:@"asteroid"];
            asteroid.hidden = YES;
            [asteroid setXScale:0.5];
            [asteroid setYScale:0.5];
            [_asteroids addObject:asteroid];
            [self addChild:asteroid];
        }
        
#pragma mark - Setup the lasers
        _shipLasers = [[NSMutableArray alloc] initWithCapacity:kNumLasers];
        for (int i = 0; i < kNumLasers; ++i) {
            SKSpriteNode *shipLaser = [SKSpriteNode spriteNodeWithImageNamed:@"laserbeam_blue"];
            //SKSpriteNode *shipLaser = [SKSpriteNode spriteNodeWithTexture:laserTexture];
            shipLaser.hidden = YES;
            [_shipLasers addObject:shipLaser];
            [self addChild:shipLaser];
        }
        
#pragma mark - Ship movement using Joystick
        
        //  move the ship using Sprite Kit's Physics Engine
        //1 Create a rectangular physics body the same size as the ship.
        _ship.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:_ship.frame.size];
        
        //2 Make the shape dynamic; this makes it subject to things such as collisions and other outside forces.
        _ship.physicsBody.dynamic = YES;
        
        //3 You don’t want the ship to drop off the bottom of the screen, so you indicate that it’s not affected by gravity.
        _ship.physicsBody.affectedByGravity = NO;
        
        //4 Give the ship an arbitrary mass so that its movement feels natural.
        _ship.physicsBody.mass = 0.02;
        
        
        // Moving joystick code
        moveJoystick = [[KAZ_JoystickNode alloc] init];
        [moveJoystick setOuterControl:@"outer" withAlpha:0.25];
        [moveJoystick setInnerControl:@"inner" withAlpha:0.5];
        moveJoystick.speed = 8;
        [self addChild:moveJoystick];
        
        // Shooting joystick code, also setting default angle for shots
        shootJoystick = [[KAZ_JoystickNode alloc] init];
        [shootJoystick setOuterControl:@"outer" withAlpha:0.25];
        [shootJoystick setInnerControl:@"inner" withAlpha:0.5];
        shootJoystick.defaultAngle = 0; // Default angle to report straight right for firing towards the right
        [self addChild:shootJoystick];

        
        
#pragma mark - Setup the stars to appear as particles
        //Add particles
        [self addChild:[self loadEmitterNode:@"stars1"]];
        [self addChild:[self loadEmitterNode:@"stars2"]];
        [self addChild:[self loadEmitterNode:@"stars3"]];
        
        [self startBackgroundMusic];


#pragma mark - Start the actual game
        [self startTheGame];
    }
    return self;
}


- (SKEmitterNode *)loadEmitterNode:(NSString *)emitterFileName
{
    NSString *emitterPath = [[NSBundle mainBundle] pathForResource:emitterFileName ofType:@"sks"];
    SKEmitterNode *emitterNode = [NSKeyedUnarchiver unarchiveObjectWithFile:emitterPath];
    
    //do some view specific tweaks
    emitterNode.particlePosition = CGPointMake(self.size.width/2.0, self.size.height/2.0);
    emitterNode.particlePositionRange = CGVectorMake(self.size.width+100, self.size.height);
    
    return emitterNode;
    
}


- (void)didMoveToView:(SKView *)view
{
    
    
}


#pragma mark - Start the Game
- (void)startTheGame
{
    _lives = 3;
    double curTime = CACurrentMediaTime();
    _gameOverTime = curTime + 30.0;
    _nextAsteroidSpawn = 0;
    _gameOver = NO;
    
    for (SKSpriteNode *asteroid in _asteroids) {
        asteroid.hidden = YES;
    }
    
    for (SKSpriteNode *laser in _shipLasers) {
        laser.hidden = YES;
    }
    _ship.hidden = NO;
    //reset ship position for new game
    _ship.position = CGPointMake(self.frame.size.width * 0.1, CGRectGetMidY(self.frame));
    

}




- (void)startBackgroundMusic
{
    NSError *err;
    NSURL *file = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SpaceGame.caf" ofType:nil]];
    _backgroundAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:file error:&err];
    if (err) {
        NSLog(@"error in audio play %@",[err userInfo]);
        return;
    }
    [_backgroundAudioPlayer prepareToPlay];
    
    // this will play the music infinitely
    _backgroundAudioPlayer.numberOfLoops = -1;
    [_backgroundAudioPlayer setVolume:1.0];
    [_backgroundAudioPlayer play];
}



// Add new method, above update loop
- (float)randomValueBetween:(float)low andValue:(float)high {
    return (((float) arc4random() / 0xFFFFFFFFu) * (high - low)) + low;
}


-(void)update:(NSTimeInterval)currentTime {
    /* Called before each frame is rendered */
    
    //Update background (parallax) position
    [_parallaxSpaceDust update:currentTime];
    
    [_parallaxNodeBackgrounds update:currentTime];    //other additional game background
    
    //Update ship's position
    
    if ( moveJoystick.isMoving ){
        CGPoint adjustedSpritePosition = CGPointMake(_ship.position.x + moveJoystick.moveSize.width, _ship.position.y + moveJoystick.moveSize.height);
        _ship.position = adjustedSpritePosition;
    }
    
    //Spawn asteroids
    double curTime = CACurrentMediaTime();
    if (curTime > _nextAsteroidSpawn) {
        //NSLog(@"spawning new asteroid");
        float randSecs = [self randomValueBetween:0.20 andValue:1.0];
        _nextAsteroidSpawn = randSecs + curTime;
        
        float randY = [self randomValueBetween:0.0 andValue:self.frame.size.height];
        float randDuration = [self randomValueBetween:2.0 andValue:10.0];
        
        SKSpriteNode *asteroid = [_asteroids objectAtIndex:_nextAsteroid];
        _nextAsteroid++;
        
        if (_nextAsteroid >= _asteroids.count) {
            _nextAsteroid = 0;
        }
        
        [asteroid removeAllActions];
        asteroid.position = CGPointMake(self.frame.size.width+asteroid.size.width/2, randY);
        asteroid.hidden = NO;
        
        CGPoint location = CGPointMake(-self.frame.size.width-asteroid.size.width, randY);
        
        SKAction *moveAction = [SKAction moveTo:location duration:randDuration];
        SKAction *doneAction = [SKAction runBlock:(dispatch_block_t)^() { 
            //NSLog(@"Animation Completed");
            asteroid.hidden = YES;
        }];
        
        SKAction *moveAsteroidActionWithDone = [SKAction sequence:@[moveAction,doneAction ]];
        
        [asteroid runAction:moveAsteroidActionWithDone withKey:@"asteroidMoving"];
    }
    
    //You may be wondering why the asteroids are exploding and still hitting us while in the game over screen!
    //Need to set our update loop to take into account the game is over, as well as keep the background moving!
    //The following if check prevents this from happening
    if (!_gameOver) {
        //check for laser collision with asteroid
        for (SKSpriteNode *asteroid in _asteroids) {
            if (asteroid.hidden) {
                continue;
            }
            for (SKSpriteNode *shipLaser in _shipLasers) {
                if (shipLaser.hidden) {
                    continue;
                }
                
                if ([shipLaser intersectsNode:asteroid]) {
                    
                    SKAction *asteroidExplosionSound = [SKAction playSoundFileNamed:@"explosion_small.caf" waitForCompletion:NO];
                    [asteroid runAction:asteroidExplosionSound];
                    
                    shipLaser.hidden = YES;
                    asteroid.hidden = YES;
                    
//                    _score += 1;
                    
                    //NSLog(@"you just destroyed an asteroid");
                    continue;
                }
            }
            if ([_ship intersectsNode:asteroid]) {
                asteroid.hidden = YES;
                SKAction *blink = [SKAction sequence:@[[SKAction fadeOutWithDuration:0.1],
                                                       [SKAction fadeInWithDuration:0.1]]];
                SKAction *blinkForTime = [SKAction repeatAction:blink count:4];
                SKAction *shipExplosionSound = [SKAction playSoundFileNamed:@"explosion_large.caf" waitForCompletion:NO];
                [_ship runAction:[SKAction sequence:@[shipExplosionSound,blinkForTime]]];
                _lives--;
                NSLog(@"your ship has been hit!");
            }
        }
    



        
        // handle whether we are game over
        if (_lives <= 0) {
            NSLog(@"you lose...");
            [self endTheScene:kEndReasonLose];
        } else if (curTime >= _gameOverTime) {
            NSLog(@"you won...");
            [self endTheScene:kEndReasonWin];
        }
    }
    
}



- (void)endTheScene:(EndReason)endReason {
    if (_gameOver) {
        return;
    }
    
    [self removeAllActions];
    _ship.hidden = YES;
    _gameOver = YES;
    
    NSString *message;
    if (endReason == kEndReasonWin) {
        message = @"You win!";
    } else if (endReason == kEndReasonLose) {
        message = @"You lost!";
    }
    
    SKLabelNode *label;
    label = [[SKLabelNode alloc] initWithFontNamed:@"Futura-CondensedMedium"];
    label.name = @"winLoseLabel";
    label.text = message;
    label.scale = 0.1;
    label.position = CGPointMake(self.frame.size.width/2, self.frame.size.height * 0.6);
    label.fontColor = [SKColor yellowColor];
    [self addChild:label];
    
    SKLabelNode *restartLabel;
    restartLabel = [[SKLabelNode alloc] initWithFontNamed:@"Futura-CondensedMedium"];
    restartLabel.name = @"restartLabel";
    restartLabel.text = @"Play Again?";
    restartLabel.scale = 0.5;
    restartLabel.position = CGPointMake(self.frame.size.width/2, self.frame.size.height * 0.4);
    restartLabel.fontColor = [SKColor yellowColor];
    [self addChild:restartLabel];
    
    SKLabelNode *titleScreen;
    titleScreen = [[SKLabelNode alloc] initWithFontNamed:@"Futura-CondensedMedium"];
    titleScreen.name = @"titleScreen";
    titleScreen.text = @"Return to Title";
    titleScreen.scale = 0.5;
    titleScreen.position = CGPointMake(self.frame.size.width/2, self.frame.size.height * 0.2);
    titleScreen.fontColor = [SKColor yellowColor];
    [self addChild:titleScreen];
    

    
    
    
    
    SKAction *labelScaleAction = [SKAction scaleTo:1.0 duration:0.5];
    
    [restartLabel runAction:labelScaleAction];
    [label runAction:labelScaleAction];
    [titleScreen runAction:labelScaleAction];

    
}

@end