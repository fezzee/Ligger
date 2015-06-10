//
//  GameScene.m
//  Ligger
//
//  Created by Gene Myers on 13/04/2015.
//  Copyright (c) 2015 Fezzee Ltd. All rights reserved.
//

#import "GameScene.h"
#import "LevelTimer.h"

@implementation GameScene
{
    __weak CCNode* _levelNode;
    __weak CCPhysicsNode* _physicsNode;
    __weak CCNode* _playerNode;
    __weak CCNode* _backgroundNode;
}

static Boolean halt = false;
//a static implemntation of Halt
+ (Boolean) halt { return halt; }
+ (void) setHalt:(Boolean)value { halt = value; }


int idxBartender = 0;//the current choosen bartender
int cntBartender = 0; //current bartender frame count
int ttBartender = 0; //the total time for this bartender round
bool bBartenderServing = false;
bool isPromotorSetupStarted = false;
bool isCollisionInProgress = false;

-(void) didLoadFromCCB
{
    
    NSLog(@"GameScene created, Level: %@", _levelNode);
    self.levelState = GameSetup;
    
    // load the current level
    [self loadLevelNamed:nil];
    
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [[[CCDirector sharedDirector] view] addGestureRecognizer:swipeLeft];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self  action:@selector(handleSwipeGesture:)];
    ;swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [[[CCDirector sharedDirector] view] addGestureRecognizer:swipeRight];
    
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc]  initWithTarget:self action:@selector(handleSwipeGesture:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    //[self addGestureRecognizer:swipeUp];
    [[[CCDirector sharedDirector] view] addGestureRecognizer:swipeUp];
    
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [[[CCDirector sharedDirector] view] addGestureRecognizer:swipeDown];
    
    // enable receiving input events
    self.userInteractionEnabled = YES;
    
    CGSize winSize = [[CCDirector sharedDirector] viewSize];
    self.screenWidth = winSize.width;
    self.screenHeight = winSize.height;
    
    _timer = [[LevelTimer alloc] initWithGame:self x:20 y:self.screenHeight-20];
    
}
 
-(void) exitButtonPressed
{
    NSLog(@"exitButtonPressed");
    
    CCScene* scene = [CCBReader loadAsScene:@"MainScene"];
    CCTransition* transition = [CCTransition transitionFadeWithDuration:1.5];
    [[CCDirector sharedDirector] presentScene:scene withTransition:transition];
}

-(void) gameOver
{
    NSLog(@"Game Over*****************");
    
    NSLog(@"Game Duration: %d",((LevelTimer*)_timer).seconds);
    [self pauseGame];
}

- (CCNode*) getScreen
{
    return self;
}

-(void) loadLevelNamed:(NSString*)levelCCB
{
    // get the current level's player in the scene by searching for it recursively
    _playerNode = [self getChildByName:@"player1m" recursively:TRUE];
    self.playerState = NoBeers;
    NSAssert1(_playerNode, @"player node not found in level: %@", levelCCB);
    
    self.obstacle1 = [self getChildByName:@"obstacle1" recursively:YES];
    self.obstacle2 = [self getChildByName:@"obstacle2" recursively:YES];
    self.obstacle3 = [self getChildByName:@"obstacle3" recursively:YES];
    self.obstacle4 = [self getChildByName:@"obstacle4" recursively:YES];
    self.obstacle5 = [self getChildByName:@"obstacle5" recursively:YES];
    self.obstacle6 = [self getChildByName:@"obstacle6" recursively:YES];
    self.obstacle7 = [self getChildByName:@"obstacle7" recursively:YES];
    self.obstacle8 = [self getChildByName:@"obstacle8" recursively:YES];
    self.obstacle9 = [self getChildByName:@"obstacle9" recursively:YES];
    self.obstacle10 = [self getChildByName:@"obstacle10" recursively:YES];
    self.obstacle11 = [self getChildByName:@"obstacle11" recursively:YES];
    
    self.obstacles = [NSMutableArray arrayWithObjects:self.obstacle1,self.obstacle2,self.obstacle3,self.obstacle4,self.obstacle5,self.obstacle6,self.obstacle7,self.obstacle8,self.obstacle9,self.obstacle10,self.obstacle11, nil];
    
    self.bartender1 = [self getChildByName:@"bartender1" recursively:YES];
    
    self.promotor1 = [self getChildByName:@"promotor1" recursively:YES];
    self.promotor2 = [self getChildByName:@"promotor2" recursively:YES];
    self.promotor3 = [self getChildByName:@"promotor3" recursively:YES];
    self.promotor4 = [self getChildByName:@"promotor4" recursively:YES];
    
    self.promotors = [NSMutableArray arrayWithObjects:self.promotor1, self.promotor2,self.promotor3,self.promotor4, nil];
    
    self.bkstage_f = [self getChildByName:@"backstage-front" recursively:YES];
    self.bkstage_b = [self getChildByName:@"backstage-back" recursively:YES];
    NSAssert1(self.bkstage_f, @"backstage-front node not found in level: %@", levelCCB);
    NSAssert1(self.bkstage_b, @"backstage-back node not found in level: %@", levelCCB);
    
    [self startGame];
}

-(void) update:(CCTime)delta
{
    //HACK:
   if (isCollisionInProgress) return;
    
   if (!GameScene.halt)
   {
        //NSLog(@"Player Row: %f",_playerNode.position.y);
        // update scroll node position to player node, with offset to center player in the view
        [self scrollToTarget:_playerNode];
       
        [self moveObstacles];
       
        if (self.levelState==GameSetup)
        {
            [self advancePromotor];
        }
        else if (self.levelState==PlayGame)
        {
            [self moveBartender];
        }
       else if (self.levelState==CompleteLevel)
       {
           [self completeLevel];
       }
       else if (self.levelState==LevelUp)
       {
           [self LevelUp];
       }
   }
}

-(Boolean) doesCollide:(CCNode*)obstacle withPlayer:(CCNode*) player
{
    Boolean rtn = false;
    CGPoint obstacleWorld = [obstacle convertToWorldSpace:obstacle.position];
    CGPoint playerWorld = [player convertToWorldSpace: player.position];
    if (obstacleWorld.y >= playerWorld.y - player.boundingBox.size.height && obstacleWorld.y - obstacle.boundingBox.size.height <= playerWorld.y)
    {
        //and the horizontal axis collides
        if (obstacleWorld.x + obstacle.boundingBox.size.width >= playerWorld.x && obstacleWorld.x <= + playerWorld.x + player.boundingBox.size.height)
        {
            rtn = true;//doesCollide
        }
    }
  
    return rtn;
}

-(Boolean) isServing:(int)idxBartender withPlayer:(CCNode*) player
{
    Boolean rtn = false;
    CGPoint playerWorld = [player convertToWorldSpace: player.position];
    int idxPlayer = playerWorld.x;
    //NSLog(@"Player at bar: %d Bartender: %d",idxPlayer,indexBartender);
    //NSLog(@"Player at bar pos: %d Bartender: %d Row: %f %f",idxPlayer/108,idxBartender*2,player.position.y,playerWorld.y);
    if (player.position.y>800 && ((idxPlayer/108)==(idxBartender*2)))
    {
        if (! bBartenderServing)
        {
            NSLog(@"PLAYER %d being Served",(idxPlayer/108)/2);
            rtn= TRUE;
        }
    }
    
    return rtn;
}

-(void) moveObstacles
{
    //Move the OBSTACLES across the screen
    for (int i = 0; i < self.obstacles.count; i++)
    {
        CCNode *obstacle = self.obstacles[i];

        obstacle.position = ccpSub(obstacle.position, ccp((i % 2)?3.0:-3.0,0));

        //check for collisions first
        if ([self doesCollide:obstacle withPlayer:_playerNode])
        {
            NSLog(@"++++ COLLIDE ++++++");

            if (self.playerState==TwoBeers)
            {
                //Partical SPLASH!
                NSLog(@"++++ SPLASH 2Beers++++++");
                
                [self particleEffect:_playerNode loadCCBName:@"Prefabs/Splash"];

                self.playerState=OneBeer;
                [self performSelector:@selector(startHustleDown) withObject:nil];
                
                [self performSelector:@selector(pauseGame) withObject:nil];
                [self performSelector:@selector(resetGame) withObject:nil afterDelay:0.5f];
                [self performSelector:@selector(startGame) withObject:nil];
                //[self performSelector:@selector(movePlayerToMedian) withObject:nil afterDelay:1.5f];
                
                //this is set to false in method movePlayerToMedian
                isCollisionInProgress = true;
                
                //[NSThread sleepForTimeInterval:0.1f];
            }
            else //if NoBeers or OneBeer- Stop
            {
                NSLog(@"++++ SPLASH ++++++");
                
                [self pauseGame];
                [self particleEffect:_playerNode loadCCBName:@"Prefabs/Splash"];
                [self performSelector:@selector(restartSetup) withObject:nil afterDelay:1.5f];
                
            }
            return;
        }
        
        if (i%2)
        {
            //Check if they have gone off screen, if they have reposition them
            if (obstacle.position.x < -obstacle.contentSize.width )
            {
                obstacle.position = ccp(_levelNode.contentSizeInPoints.width+obstacle.contentSize.width+45,obstacle.position.y);
                //NSLog(@"Offscreen");
            }
            
        } else {
            //Check if they have gone off screen to the right, if they have reposition them
            if (obstacle.position.x > _levelNode.contentSizeInPoints.width+45 )
            {
                obstacle.position = ccp(0-obstacle.contentSize.width+45,obstacle.position.y);
                //NSLog(@"Offscreen");
            }
        }
    }

}



-(void) moveBartender
{
    if (bBartenderServing || (self.playerState == TwoBeers)) return; //stops re-entry issues
    
    //Move the bartender and time his stay
    if (0==cntBartender)  //first pass,
    {

        // generate a real number between 0 and 5 - the number of bars
        int oldIdx = idxBartender;
        //this loop gets a new random Character if it matches the previous Character
        while (idxBartender==oldIdx) {
            idxBartender = (int)(arc4random() % (5*1000)) / 1000.f; //5 is the number of Bars
        }
        
        // generate a random number between kStartOffset and kStopOffset+kStartOffset
        float stay = ((arc4random() % (kStopOffset *1000)) / 1000.f)+ kStartOffset;//kStartOffset is the starting number of secs
        //NSLog(@"Bartender Stay %f", stay);
        
        ttBartender = stay * 60; //stay in secs mult by 60 fps
        
        int point = (72+(105*idxBartender)+1); //72 & 105- magic numbers
        //this gets a random character- no longer used
        //((CCNode*)self.bartenders[idxBartender]).position = CGPointMake( point, ((CCNode*)self.bartenders[idxBartender]).position.y);
        ((CCNode*)self.bartender1).position = CGPointMake( point, ((CCNode*)self.bartender1).position.y);
        
        //if ([self doesCollide:self.bartenders[idxBartender] withPlayer:_playerNode])
        if ([self isServing:idxBartender withPlayer:_playerNode])
        {
            NSLog(@"BARTENDER %d SERVING(1)", idxBartender);
            [self performSelector:@selector(serve2Beers) withObject:nil];
            bBartenderServing = true;
        }
        
        cntBartender = 1;
        
    }
    else if (cntBartender==ttBartender)
    {
        //TODO - Time still wrong....
        NSLog(@"BARTENDER RESET: Cnt: %d Secs: %d", cntBartender, ttBartender/60);
        cntBartender = 0;
    }
    else
    {
        
        //if we know we're already serving, dont check again
        if ([self isServing:idxBartender withPlayer:_playerNode])
        {
            bBartenderServing = true;
            NSLog(@"BARTENDER %d SERVING(2)", idxBartender);
            [self performSelector:@selector(serve2Beers) withObject:nil];
            
             //turn the ligger around
            [self performSelector:@selector(faceHustleDown) withObject:nil  afterDelay:1.5f];
            //reset the bartender- folder arms
            [self performSelector:@selector(nextCustomer) withObject:nil afterDelay:1.5f];
            //forces it restart timer
            cntBartender=0;
            
        }
        else
        {

            cntBartender += 1;
        }
    }

}

-(void) advancePromotor
{
    if (self.promotors.count==0)
    {
        NSLog(@"No more promotors******");
        //next level
        
        //TODO Temp!!!!
        CCScene* scene = [CCBReader loadAsScene:@"MainScene"];
        CCTransition* transition = [CCTransition transitionFadeWithDuration:1.5];
        [[CCDirector sharedDirector] presentScene:scene withTransition:transition];
        
        return;
    }
    
    if (!isPromotorSetupStarted)
    {
        [self performSelector:@selector(startAnimation:forSequence:) withObject:((CCNode*)self.promotors[0]) withObject:@"walk"];
        isPromotorSetupStarted = true;
    }
    
    if (((CCNode*)self.promotors[0]).position.x < 250)
    {
        ((CCNode*)self.promotors[0]).position = ccpSub(((CCNode*)self.promotors[0]).position, ccp(-1.0,0));
    }
    else
    {
        [self pauseAnimation:(CCNode*)self.promotors[0]];
        //just face the Ligger Up
        [self performSelector:@selector(faceHustleUp) withObject:nil];
        isPromotorSetupStarted = false;
        self.levelState = PlayGame;
        [((LevelTimer*)_timer) startTimer];
        NSLog(@"GAME LEVELTIMER STARTED");
    }
}

-(void) completeLevel
{
    if (_playerNode.position.x > 281)
    {
        //move to left
        _playerNode.position = ccpSub(_playerNode.position, ccp(1.0,0));
    }
    else
    {
        //particle explosion
        //walk the ligger to right
        [self performSelector:@selector(walkRight) withObject:nil];
        //start promotor animation
        [self performSelector:@selector(startAnimation:forSequence:) withObject:((CCNode*)self.promotors[0]) withObject:@"walk"];
        (self.levelState=LevelUp);
        NSLog(@"+++++++START LEVELUP SEQUENCE+++++++");
    }
    
}

-(void) LevelUp
{
    [((LevelTimer*)_timer) pauseTimer];
    NSLog(@"GAME LEVELTIMER PAUSED");
    
    _playerNode.position = ccpSub(_playerNode.position, ccp(-1.0,0));

    ((CCNode*)self.promotors[0]).position = ccpSub(((CCNode*)self.promotors[0]).position, ccp(-1.0,0));


    //move the backstage entrance until it gets to its final point
    if (self.bkstage_b.position.x > 498.5)
    {
        self.bkstage_f.position = ccpSub(self.bkstage_f.position, ccp(1.0,0));
        self.bkstage_b.position = ccpSub(self.bkstage_b.position, ccp(1.0,0));
    }
    
    //Check if the promotor has gone off screen
    
    if (((CCNode*)self.promotors[0]).position.x > _levelNode.contentSizeInPoints.width+45)
    {
        NSLog(@"PROMOTOR Offscreen");
        //remove the promotor- Should Promotors collection be global?
        //[self.promotors removeObjectAtIndex:0];
        //LevelUp
        
        NSLog(@"Seconds: %d",((LevelTimer*)_timer).seconds);
        
        //TODO Temp!!!!
        CCScene* scene = [CCBReader loadAsScene:@"MainScene"];
        CCTransition* transition = [CCTransition transitionFadeWithDuration:1.5];
        [[CCDirector sharedDirector] presentScene:scene withTransition:transition];
        

    }
}

/*
 * removed the current promotor from the collection and
 * then set the state to GameSetup and restarts animations
 */
-(void) restartSetup
{
    [((CCNode*)self.promotors[0]) removeFromParent];
    [self.promotors removeObjectAtIndex:0];
    self.playerState=NoBeers;
    //just face the Ligger Up
    [self performSelector:@selector(faceHustleUp) withObject:nil];
    //put the Ligger back at the start position
    _playerNode.position = ccp(280.268311,48.001999);
    self.levelState = GameSetup;
    [self startGame];
}


-(void) scrollToTarget:(CCNode*)target
{
    CGSize viewSize = [CCDirector sharedDirector].viewSize;
    CGPoint viewCenter = CGPointMake(viewSize.width / 2.0, viewSize.height / 2.0);
    CGPoint viewPos = ccpSub(target.positionInPoints, viewCenter);
    CGSize levelSize = _levelNode.contentSizeInPoints;
    viewPos.x = MAX(0.0, MIN(viewPos.x, levelSize.width - viewSize.width));
    viewPos.y = MAX(0.0, MIN(viewPos.y, levelSize.height - viewSize.height));
    _levelNode.positionInPoints = ccpNeg(viewPos);
}

- (void)startAnimation:(CCNode*)node forSequence:(NSString*)sequenceName
{
    // the animation manager of each node is stored in the 'animationManager' property
    CCAnimationManager* animationManager = node.animationManager;
    // timelines can be referenced and run by name
    [animationManager runAnimationsForSequenceNamed:sequenceName];
}

- (void)pauseAnimation:(CCNode*)node
{
    // the animation manager of each node is stored in the 'animationManager' property
    CCAnimationManager* animationManager = node.animationManager;
    [animationManager setPaused:YES];
}

//
- (void) particleEffect:(CCNode*)node loadCCBName:(NSString*)particleCCB
{
    // load particle effect
    CCParticleSystem *explosion = (CCParticleSystem *)[CCBReader load:particleCCB];
    NSAssert( explosion != nil, @"Particle Effect must be non-nil");
    // make the particle effect clean itself up, once it is completed
    explosion.autoRemoveOnFinish = TRUE;
    // place the particle effect on the players position
    explosion.position = node.position;
    // add the particle effect to the same node the player is on
    [node.parent addChild:explosion];
}

- (void)serve2Beers
{
    CCAnimationManager* animationManager = _bartender1.animationManager;
    [animationManager runAnimationsForSequenceNamed:@"Serve2Beers"];
    //set the player to 2Beers state
    self.playerState = TwoBeers;

}

- (void) nextCustomer
{
    CCAnimationManager* animationManager = _bartender1.animationManager;
    [animationManager runAnimationsForSequenceNamed:@"empty"];
    
}

/*
 * NO LONGER USED
 * used to move Player to the Median
 * in a method so you can call it after a delay
 * eg: [self performSelector:@selector(movePlayerToMedian) withObject:nil afterDelay:1.5f];
 */
-(void) movePlayerToMedian
{
    NSLog(@"Moving Player to Median");
    _playerNode.position = CGPointMake(_playerNode.position.x,kMedianStripRow);
    [self scrollToTarget:_playerNode];
    //very important if this is called with a delay- stops reentry
    isCollisionInProgress = false;
}


- (void)startHustleRight
{
    self.playerMoveState = PlayerRight;
    
    //restarts the bartender animation
    if (bBartenderServing)
    {
        bBartenderServing = FALSE;
    }
    
    // the animation manager of each node is stored in the 'animationManager' property
    CCAnimationManager* animationManager = _playerNode.animationManager;
    // timelines can be referenced and run by name
    switch (self.playerState) {
        case TwoBeers:
            [animationManager runAnimationsForSequenceNamed:@"HustleRight-2Beers"];
            break;
        case OneBeer:
            [animationManager runAnimationsForSequenceNamed:@"HustleRight-1Beer"];
            break;
        default: //NoBeers
            [animationManager runAnimationsForSequenceNamed:@"HustleRight"];
            break;
    }

}

- (void)walkRight
{
    
    // the animation manager of each node is stored in the 'animationManager' property
    CCAnimationManager* animationManager = _playerNode.animationManager;
    // timelines can be referenced and run by name
    switch (self.playerState) {
        case TwoBeers:
            [animationManager runAnimationsForSequenceNamed:@"WalkRight-2Beers"];
            break;
        case OneBeer:
            [animationManager runAnimationsForSequenceNamed:@"WalkRight-1Beer"];
            break;
    }
    
}

- (void)startHustleLeft
{
    self.playerMoveState = PlayerLeft;
    
    //restarts the bartender animation
    if (bBartenderServing)
    {
        bBartenderServing = FALSE;
    }
    
    // the animation manager of each node is stored in the 'animationManager' property
    CCAnimationManager* animationManager = _playerNode.animationManager;
    // timelines can be referenced and run by name
    switch (self.playerState) {
        case TwoBeers:
            [animationManager runAnimationsForSequenceNamed:@"HustleLeft-2Beers"];
            break;
        case OneBeer:
            [animationManager runAnimationsForSequenceNamed:@"HustleLeft-1Beer"];
            break;
        default: //NoBeers
            [animationManager runAnimationsForSequenceNamed:@"HustleLeft"];
            break;
    }
}

- (void)startHustleUp
{
    self.playerMoveState = PlayerUp;
    self.moveLength = 64;//kVERTICALMOVE;
    
    // the animation manager of each node is stored in the 'animationManager' property
    CCAnimationManager* animationManager = _playerNode.animationManager;
    switch (self.playerState) {
        case TwoBeers:
            [animationManager runAnimationsForSequenceNamed:@"HustleUp-2Beers"];
            break;
        case OneBeer:
            [animationManager runAnimationsForSequenceNamed:@"HustleUp-1Beer"];
            break;
        default: //NoBeers
            [animationManager runAnimationsForSequenceNamed:@"HustleUp"];
            break;
    }
    
}

/*
 * Fce the Ligger Up (back) with NoBeers
 */
- (void)faceHustleUp
{
    
    // the animation manager of each node is stored in the 'animationManager' property
    CCAnimationManager* animationManager = _playerNode.animationManager;

   [animationManager runAnimationsForSequenceNamed:@"FaceUp"];

    
}

/*
 * Face the Ligger Down(front) with TwoBeers
 */
- (void)faceHustleDown
{
    
    // the animation manager of each node is stored in the 'animationManager' property
    CCAnimationManager* animationManager = _playerNode.animationManager;
    
    [animationManager runAnimationsForSequenceNamed:@"FaceDown2"];
    
    
}




- (void)startHustleDown
{
    self.playerMoveState = PlayerDown;
    
    //restarts the bartender animation
    if (bBartenderServing)
    {
        bBartenderServing = FALSE;
    }
    
    // the animation manager of each node is stored in the 'animationManager' property
    CCAnimationManager* animationManager = _playerNode.animationManager;
    // timelines can be referenced and run by name
    switch (self.playerState) {
        case TwoBeers:
            [animationManager runAnimationsForSequenceNamed:@"HustleDown-2Beers"];
            break;
        case OneBeer:
            [animationManager runAnimationsForSequenceNamed:@"HustleDown-1Beer"];
            break;
        default: //NoBeers
            [animationManager runAnimationsForSequenceNamed:@"HustleDown"];
            break;
    }
}

//moves and animated the character
-(void)handleSwipeGesture:(UISwipeGestureRecognizer *) sender
{
    if (GameScene.halt) return;
    
    switch( sender.direction ) {
        case UISwipeGestureRecognizerDirectionUp:
            NSLog(@"SwipeUp");
            if (self.levelState==PlayGame)
            {
                if ((_playerNode.position.y) < kBOARDTOPBOUND) //keeps with top boundry
                {
                    _playerNode.position = CGPointMake(_playerNode.position.x,_playerNode.position.y+kVERTICALMOVE);
                    [self performSelector:@selector(startHustleUp) withObject:nil];
                }
            }
            break;
        case UISwipeGestureRecognizerDirectionDown:
            NSLog(@"SwipeDown");
            if (self.levelState==PlayGame)
            {
                if ((_playerNode.position.y) > kBOARDBOTTOMBOUND ) //keeps with bottom boundry
                {
                    NSLog(@"Player Row: %f Column: %f",_playerNode.position.y, _playerNode.position.x);
                    //dont let the Ligger enter the Promotor area
                    //TODO: make constants
                    if (_playerNode.position.y < 113 && (_playerNode.position.x < 229|| _playerNode.position.x > 436)) break;
                    
                    _playerNode.position = CGPointMake(_playerNode.position.x,_playerNode.position.y-kVERTICALMOVE);
                    [self performSelector:@selector(startHustleDown) withObject:nil];
                    
                    //if we move away from the bar, right, left or down, reset the bartender
                    
                    //if we get back to the promotors area with a beers or two, we're done
                    if (_playerNode.position.y < 110 && self.playerState != NoBeers)
                    {
                       NSLog(@"+++++++LEVEL COMPLETED+++++++");
                        self.levelState=CompleteLevel;
  
                        [self performSelector:@selector(startHustleLeft) withObject:nil];
                       
                    } else {
                        NSLog(@"NOT COMPLETED LEVEL, Y: %f PlayerState: %d",_playerNode.position.y,self.playerState != NoBeers);
                    }
                }
            }
            break;
        case UISwipeGestureRecognizerDirectionLeft:
            NSLog(@"SwipeLeft");
            if (self.levelState==PlayGame)
            {
                if ((_playerNode.position.x) > kBOARDLEFTBOUND) //keeps with left boundry
                {
                    NSLog(@"Player Row: %f Column: %f",_playerNode.position.y, _playerNode.position.x);
                    //dont let the Ligger enter the Promotor area
                    //TODO- CONSTANTS!!
                    if (_playerNode.position.y < 49 && _playerNode.position.x < 281) break;
                    

                    _playerNode.position = CGPointMake(_playerNode.position.x-kHORIZONTALMOVE,_playerNode.position.y);
                    [self performSelector:@selector(startHustleLeft) withObject:nil];
                }
            }
            break;
        case UISwipeGestureRecognizerDirectionRight:
            NSLog(@"SwipeRight");
            if (self.levelState==PlayGame)
            {
                
                if ((_playerNode.position.x) < kBOARDRIGHTBOUND) //keeps with right boundry
                {
                    if (_playerNode.position.y < 49 && _playerNode.position.x > 384) break;
                    
                    NSLog(@"Player Row: %f Column: %f",_playerNode.position.y, _playerNode.position.x);
                    _playerNode.position = CGPointMake(_playerNode.position.x+kHORIZONTALMOVE,_playerNode.position.y);
                    [self performSelector:@selector(startHustleRight) withObject:nil];
                }
            }
            break;
    }
    
}

-(void) startGame
{
    //NSLog(@"PLAYER START POS- x:%f y:%f Numb obstabcle: %lu",_playerNode.position.x,_playerNode.position.y,(unsigned long)self.obstacles.count);
    
    GameScene.halt = false;

    NSLog(@"ANIMATION STARTED");
    
    for (int i = 0; i < self.obstacles.count; i++)
    {
        [self performSelector:@selector(startAnimation:forSequence:) withObject:(CCNode*)self.obstacles[i] withObject:@"default"];
    }
}


-(void) pauseGame //:(CCNode*) obstacle
{
    GameScene.halt = true;
    
    [_timer pauseTimer];
    
    [self performSelector:@selector(pauseAnimation:) withObject:self.bartender1];
    
    for (int i = 0; i < self.obstacles.count; i++)
    {
        [self performSelector:@selector(pauseAnimation:) withObject:(CCNode*)self.obstacles[i]];
    }

}

-(void) resetGame //:(CCNode*) obstacle
{

    
    for (int i = 0; i < self.obstacles.count; i++)
    {

        
        if (i%2)
        {

                ((CCNode*)self.obstacles[i]).position = ccp(_levelNode.contentSizeInPoints.width+((CCNode*)self.obstacles[i]).contentSize.width+45,((CCNode*)self.obstacles[i]).position.y);

            
        } else {

                ((CCNode*)self.obstacles[i]).position = ccp(0-((CCNode*)self.obstacles[i]).contentSize.width+45,((CCNode*)self.obstacles[i]).position.y);


        }
    
        GameScene.halt = false;
        isCollisionInProgress = false;
    }
}

//-(void) touchBegan:(UITouch *)touch withEvent:(UIEvent *)event
//{
//    _playerNode.position = [touch locationInNode:self];
//}

@end
