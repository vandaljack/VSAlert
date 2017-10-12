//
//  VSAlertController.m
//  VSAlertController
//
//  Created by Varun Santhanam on 10/8/17.
//

#import <os/log.h>

#import "VSAlertController.h"
#import "VSAlertControllerTransitionAnimator.h"
#import "VSAlertControllerAppearanceProxy.h"

NSString * const VSAlertControllerNotImplementedException = @"VSAlertControllerNotImplementedException";
NSString * const VSAlertControllerTextFieldInvalidException = @"VSAlertControllerTextFieldInvalidException";

@interface VSAlertController ()<UIViewControllerTransitioningDelegate>

@property (NS_NONATOMIC_IOSONLY, strong) UIImageView *alertMaskBackgroundImageView;
@property (NS_NONATOMIC_IOSONLY, strong) UIView *alertView;
@property (NS_NONATOMIC_IOSONLY, strong) UIView *headerView;
@property (NS_NONATOMIC_IOSONLY, strong) NSLayoutConstraint *headerViewHeightConstraint;
@property (NS_NONATOMIC_IOSONLY, strong) UIImageView *alertImageView;
@property (NS_NONATOMIC_IOSONLY, strong) UILabel *alertTitleLabel;
@property (NS_NONATOMIC_IOSONLY, strong) NSLayoutConstraint *alertTitleLabelHeightConstraint;
@property (NS_NONATOMIC_IOSONLY, strong) UILabel *alertMessageLabel;
@property (NS_NONATOMIC_IOSONLY, strong) UIStackView *alertActionStackView;
@property (NS_NONATOMIC_IOSONLY, strong) NSLayoutConstraint *alertActionStackViewHeightConstraint;
@property (NS_NONATOMIC_IOSONLY, strong) UITapGestureRecognizer *tapRecognizer;

@property (NS_NONATOMIC_IOSONLY, readonly) CGFloat alertStackViewHeight;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL hasTextFieldAdded;

// Re-designate initializers so you can call 'super'
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil NS_DESIGNATED_INITIALIZER;

@end

@implementation VSAlertController {
    
    // Actions
    NSArray<VSAlertAction *> *_defaultActions;
    NSArray<VSAlertAction *> *_destructiveActions;
    NSArray<VSAlertAction *> *_cancelActions;
    
    // Keyboard Show / Hide
    CGPoint _tempFrameOrigin;
    BOOL _keyboardHasBeenShown;
    
    // Transition
    VSAlertControllerTransitionAnimator *_presentAnimator;
    VSAlertControllerTransitionAnimator *_dismissAnimator;
    
}

// Log
static os_log_t alert_log;

// Explicitly synthesize Ivars from header
@synthesize alertTitleTextColor = _alertTitleTextColor;
@synthesize alertMessageTextColor = _alertMessageTextColor;
@synthesize alertTitleTextFont = _alertTitleTextFont;
@synthesize alertMessageTextFont = _alertMessageTextFont;
@synthesize textfields = _textfields;
@synthesize animationStyle = _animationStyle;
@synthesize dismissOnBackgroundTap = _dismissOnBackgroundTap;
@synthesize style = _style;
@synthesize alertTitle = _alertTitle;
@synthesize message = _message;
@synthesize image = _image;
@synthesize delegate = _delegate;

// Explicitly synthesize Ivars from extension
@synthesize alertMaskBackgroundImageView = _alertMaskBackgroundImageView;
@synthesize alertView = _alertView;
@synthesize headerView = _headerView;
@synthesize headerViewHeightConstraint = _headerViewHeightConstraint;
@synthesize alertImageView = _alertImageView;
@synthesize alertTitleLabel = _alertTitleLabel;
@synthesize alertTitleLabelHeightConstraint = _alertTitleLabelHeightConstraint;
@synthesize alertMessageLabel = _alertMessageLabel;
@synthesize alertActionStackView = _alertActionStackView;
@synthesize alertActionStackViewHeightConstraint = _alertActionStackViewHeightConstraint;
@synthesize tapRecognizer = _tapRecognizer;

#pragma mark - Overridden Class Methods

+ (void)initialize {
    
    alert_log = os_log_create("com.varunsanthanam.VSAlert", "VSAlert");
    
}

#pragma mark - Public Class Methods

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image style:(VSAlertControllerStyle)style {
    
    VSAlertController *alertController = [[self alloc] initWithTitle:title
                                                             message:message
                                                               image:image
                                                               style:style];
    
    return alertController;
    
}

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message style:(VSAlertControllerStyle)style {
    
    VSAlertController *alertController = [[self alloc] initWithTitle:title
                                                             message:message
                                                               image:nil
                                                               style:style];
    
    return alertController;
    
}

#pragma mark - Overridden Instance Methods

- (instancetype)init {
    
    self = [self initWithTitle:nil
                       message:nil
                         image:nil
                         style:VSAlertControllerStyleAlert];
    
    return self;
    
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        
        // Basic setup
        [self _setUpAlertController];

    }
    
    return self;
    
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        
        // Basic setup
        [self _setUpAlertController];
        
    }
    
    return self;
    
}

#pragma mark - Overridden Instance Methods

- (void)viewDidLoad {
    
    [self _setUpAlertControllerUI];
    
    // Configure Text
    self.alertTitleLabel.text = self.alertTitle;
    self.alertMessageLabel.text = self.message;
    
    // Configure Image
    self.alertImageView.image = self.image;
    
    // Update Constraints
    self.headerViewHeightConstraint.constant = (BOOL)self.alertImageView.image ? 180.0f : 0.0f;
    self.alertTitleLabelHeightConstraint.constant = (BOOL)self.alertTitle ? self.alertTitleTextFont.pointSize + 5.0f : 0.0f;
    
    // Set Up Background Tap Gesture Recognizer If Needed
    if (self.dismissOnBackgroundTap) {
        
        self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(_dismissAlertControllerFromBackgroundTap)];
        [self.alertMaskBackgroundImageView addGestureRecognizer:self.tapRecognizer];
        
    }
    
    // Process Text Fields
    [self _processTextFields];
    
    // Process Actions
    [self _processActions];
    
    // Configure Stack
    [self _configureStack];
    
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    // Register for keyboard show/hide notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    
    [super viewDidDisappear:animated];
    
    // Unregisted for keyboard show/hide notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
}

#pragma mark - Property Access Methods

- (UIColor *)alertTitleTextColor {
    
    return _alertTitleTextColor;
    
}

- (void)setAlertTitleTextColor:(UIColor *)alertTitleTextColor {
    
    _alertTitleTextColor = alertTitleTextColor;
    self.alertTitleLabel.textColor = self.alertTitleTextColor;
    
}

- (UIFont *)alertTitleTextFont {
    
    return _alertTitleTextFont;
    
}

- (void)setAlertTitleTextFont:(UIFont *)alertTitleTextFont {
    
    _alertTitleTextFont = alertTitleTextFont;
    self.alertTitleLabel.font = self.alertTitleTextFont;
    
}

- (UIColor *)alertMessageTextColor {
    
    return _alertMessageTextColor;
    
}

- (void)setAlertMessageTextColor:(UIColor *)alertMessageTextColor {
    
    _alertMessageTextColor = alertMessageTextColor;
    self.alertMessageLabel.textColor = self.alertMessageTextColor;
    
}

- (UIFont *)alertMessageTextFont {
    
    return _alertMessageTextFont;
    
}

- (void)setAlertMessageTextFont:(UIFont *)alertMessageTextFont {
    
    _alertMessageTextFont = alertMessageTextFont;
    self.alertMessageLabel.font = self.alertMessageTextFont;
    
}

- (BOOL)hasTextFieldAdded {
    
    return self.textfields.count > 0;
    
}

- (CGFloat)alertStackViewHeight {
    
    // Shortenend Stack for iPhone 4 / 4s
    return [UIScreen mainScreen].bounds.size.height < 480.0f ? 40.0f : 62.0f;
    
}

#pragma mark - UIAppearance

+ (instancetype)appearance {
    
    return (VSAlertController *)[VSAlertControllerAppearanceProxy appearance];
    
}

+ (instancetype)appearanceForTraitCollection:(UITraitCollection *)trait {
    
    return (VSAlertController *)[VSAlertControllerAppearanceProxy appearanceForTraitCollection:trait];
    
}

+ (instancetype)appearanceForTraitCollection:(UITraitCollection *)trait whenContainedInInstancesOfClasses:(NSArray<Class<UIAppearanceContainer>> *)containerTypes {
    
    return (VSAlertController *)[VSAlertControllerAppearanceProxy appearanceForTraitCollection:trait whenContainedInInstancesOfClasses:containerTypes];
    
}

+ (instancetype)appearanceWhenContainedInInstancesOfClasses:(NSArray<Class<UIAppearanceContainer>> *)containerTypes {
    
    return (VSAlertController *)[VSAlertControllerAppearanceProxy appearanceWhenContainedInInstancesOfClasses:containerTypes];
    
}

+ (nonnull instancetype)appearanceForTraitCollection:(nonnull UITraitCollection *)trait whenContainedIn:(nullable Class<UIAppearanceContainer>)ContainerClass, ... {
    
    return nil;
    
}


+ (nonnull instancetype)appearanceWhenContainedIn:(nullable Class<UIAppearanceContainer>)ContainerClass, ... {
    
    return nil;
    
}

#pragma mark - UIViewControllerTransitioningDelegate

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    
    return _presentAnimator;
    
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    
    return _dismissAnimator;
    
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id<UIViewControllerAnimatedTransitioning>)animator {
    
    return nil;
    
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator {
    
    return nil;
    
}
#pragma mark - Public Instance Methods

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image style:(VSAlertControllerStyle)style {
    
    self = [super initWithNibName:nil bundle:nil];
    
    if (self) {
        
        // Basic setup
        [self _setUpAlertController];
        
        // Assign read-only properties
        _alertTitle = title;
        _message = message;
        _image = image;
        _style = style;
        
    }
    
    return self;
    
}

- (void)addAction:(VSAlertAction *)alertAction {
    
    // Keep actions separate because they maybe added in a different order than they maybe displayed
    if (alertAction.style == VSAlertActionStyleDefault) {
        
        _defaultActions = [_defaultActions arrayByAddingObject:alertAction];
        
    } else if (alertAction.style == VSAlertActionStyleDestructive) {
        
        _destructiveActions = [_destructiveActions arrayByAddingObject:alertAction];
        
    } else if (alertAction.style == VSAlertActionStyleCancel) {
        
        _cancelActions = [_cancelActions arrayByAddingObject:alertAction];
        
    }
    
}

- (void)addTextField:(void (^)(UITextField *))configuration {
    
    if (_style == VSAlertControllerStyleActionSheet) {
        
        [NSException raise:VSAlertControllerTextFieldInvalidException format:@"You can't add text fields to an action sheet"];
        
    }
    
    // Instantiate textfield rather than accepting textfield param
    UITextField *textfield = [[UITextField alloc] init];
    
    // Customize textfield
    textfield.returnKeyType = UIReturnKeyDone;
    textfield.font = [UIFont systemFontOfSize:17.0f];
    textfield.textAlignment = NSTextAlignmentCenter;
    [textfield addTarget:self
                  action:@selector(_closeKeyboard:)
        forControlEvents:UIControlEventEditingDidEndOnExit];
    
    // Perform configuration block on textfeild
    if (configuration) {
        
        configuration(textfield);
        
    }
    
    // Store textfield for use in -viewDidLoad
    _textfields = [_textfields arrayByAddingObject:textfield];
    
}

#pragma mark - Private Instance Methods

- (void)_setUpAlertController {
    
    // Prepare for proper modal use
    self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    
    // Take Over Transition Process
    self.transitioningDelegate = self;
    
    // Set ivar defaults
    _keyboardHasBeenShown = NO;
    _defaultActions = [[NSArray<VSAlertAction *> alloc] init];
    _destructiveActions = [[NSArray<VSAlertAction *> alloc] init];
    _cancelActions = [[NSArray<VSAlertAction *> alloc] init];
    _tempFrameOrigin = CGPointMake(0.0f, 0.0f);
    _textfields = [[NSArray<UITextField *> alloc] init];
    _presentAnimator = [[VSAlertControllerTransitionAnimator alloc] init];
    _dismissAnimator = [[VSAlertControllerTransitionAnimator alloc] init];
    
    //     Set up propertie without accessors for use with UIAppearance
    _alertTitleTextColor = [VSAlertController appearance].alertTitleTextColor ? [VSAlertController appearance].alertTitleTextColor : [UIColor blackColor];
    _alertTitleTextFont = [VSAlertController appearance].alertTitleTextFont ? [VSAlertController appearance].alertTitleTextFont : [UIFont systemFontOfSize:17.0f weight:UIFontWeightSemibold];
    _alertMessageTextColor = [VSAlertController appearance].alertMessageTextColor ? [VSAlertController appearance].alertMessageTextColor : [UIColor blackColor];
    _alertMessageTextFont = [VSAlertController appearance].alertMessageTextFont ? [VSAlertController appearance].alertMessageTextFont : [UIFont systemFontOfSize:15.0f weight:UIFontWeightRegular];
    
    // Set instance read-only properties
    _style = VSAlertControllerStyleAlert;
    _alertTitle = nil;
    _message = nil;
    _image = nil;
    
    // Set instance property defaults
    self.animationStyle = VSAlertControllerAnimationStyleAutomatic;
    self.dismissOnBackgroundTap = NO;
    
}

- (void)_setUpAlertControllerUI {
    
    /// Build alert view UI without xib
    [self _setUpAlertMaskBackgroundImageView];
    [self _setUpAlertView];
    [self _setUpHeaderView];
    [self _setUpAlertImageView];
    [self _setUpAlertTitleLabel];
    [self _setUpAlertMessageLabel];
    [self _setUpAlertActionStackView];
    
}

- (void)_setUpAlertMaskBackgroundImageView {
    
    self.alertMaskBackgroundImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.alertMaskBackgroundImageView.backgroundColor = [UIColor clearColor];
    self.alertMaskBackgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.alertMaskBackgroundImageView.userInteractionEnabled = YES;
    
    [self.view addSubview:self.alertMaskBackgroundImageView];
    
    [self.view addConstraints:@[[NSLayoutConstraint constraintWithItem:self.alertMaskBackgroundImageView
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeWidth
                                                            multiplier:1.0f
                                                              constant:0.0f],
                                [NSLayoutConstraint constraintWithItem:self.alertMaskBackgroundImageView
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeHeight
                                                            multiplier:1.0f
                                                              constant:0.0f],
                                [NSLayoutConstraint constraintWithItem:self.alertMaskBackgroundImageView
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0f
                                                              constant:0.0f],
                                [NSLayoutConstraint constraintWithItem:self.alertMaskBackgroundImageView
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0f
                                                              constant:0.0f]]];
    
}

- (void)_setUpAlertView {
    
    self.alertView = [[UIView alloc] initWithFrame:CGRectZero];
    self.alertView.backgroundColor = [UIColor whiteColor];
    self.alertView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.alertMaskBackgroundImageView addSubview:self.alertView];
    
    self.alertView.layer.cornerRadius = 5.0f;
    self.alertView.layer.masksToBounds = NO;
    self.alertView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    self.alertView.layer.shadowRadius = 8.0f;
    self.alertView.layer.shadowOpacity = 0.3f;
    
    CGFloat width = self.style == VSAlertControllerStyleAlert ? 270.0f : [UIScreen mainScreen].bounds.size.width - 36.0f;
    
    [self.view addConstraints:@[[NSLayoutConstraint constraintWithItem:self.alertView
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0f
                                                              constant:0.0f],
                                [NSLayoutConstraint constraintWithItem:self.alertView
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeHeight
                                                            multiplier:0.0f
                                                              constant:100.0f],
                                [NSLayoutConstraint constraintWithItem:self.alertView
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeWidth
                                                            multiplier:0.0f
                                                              constant:width]]];
    
    if (self.style == VSAlertControllerStyleActionSheet) {
        
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.alertView
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0f
                                                               constant:-18.0f]];
        
    } else {
        
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.alertView
                                                              attribute:NSLayoutAttributeCenterY
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeCenterY
                                                             multiplier:1.0f
                                                               constant:0.0f]];
        
    }
    
}

- (void)_setUpHeaderView {
    
    self.headerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerView.backgroundColor = [UIColor whiteColor];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.alertView addSubview:self.headerView];
    
    [self.alertView addConstraints:@[[NSLayoutConstraint constraintWithItem:self.headerView
                                                                  attribute:NSLayoutAttributeTop
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertView
                                                                  attribute:NSLayoutAttributeTop
                                                                 multiplier:1.0f
                                                                   constant:8.0f],
                                     [NSLayoutConstraint constraintWithItem:self.headerView
                                                                  attribute:NSLayoutAttributeLeft
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertView
                                                                  attribute:NSLayoutAttributeLeft
                                                                 multiplier:1.0f
                                                                   constant:0.0f],
                                     [NSLayoutConstraint constraintWithItem:self.headerView
                                                                  attribute:NSLayoutAttributeRight
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertView
                                                                  attribute:NSLayoutAttributeRight
                                                                 multiplier:1.0f
                                                                   constant:0.0f]]];
    self.headerViewHeightConstraint = [NSLayoutConstraint constraintWithItem:self.headerView
                                                                   attribute:NSLayoutAttributeHeight
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:nil
                                                                   attribute:NSLayoutAttributeHeight
                                                                  multiplier:0.0f
                                                                    constant:0.0f];
    
    [self.alertView addConstraint:self.headerViewHeightConstraint];
    
}

- (void)_setUpAlertImageView {
    
    self.alertImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.alertImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.alertImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    [self.headerView addSubview:self.alertImageView];
    
    [self.headerView addConstraints:@[[NSLayoutConstraint constraintWithItem:self.alertImageView
                                                                   attribute:NSLayoutAttributeTop
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:self.headerView
                                                                   attribute:NSLayoutAttributeTop
                                                                  multiplier:1.0f
                                                                    constant:0.0f],
                                      [NSLayoutConstraint constraintWithItem:self.alertImageView
                                                                   attribute:NSLayoutAttributeLeft
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:self.headerView
                                                                   attribute:NSLayoutAttributeLeft
                                                                  multiplier:1.0f
                                                                    constant:0.0f],
                                      [NSLayoutConstraint constraintWithItem:self.alertImageView
                                                                   attribute:NSLayoutAttributeRight
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:self.headerView
                                                                   attribute:NSLayoutAttributeRight
                                                                  multiplier:1.0f
                                                                    constant:0.0f],
                                      [NSLayoutConstraint constraintWithItem:self.alertImageView
                                                                   attribute:NSLayoutAttributeBottom
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:self.headerView
                                                                   attribute:NSLayoutAttributeBottom
                                                                  multiplier:1.0f
                                                                    constant:0.0f]]];
    
}

- (void)_setUpAlertTitleLabel {
    
    self.alertTitleLabel = [[UILabel alloc] init];
    self.alertTitleLabel.font = self.alertTitleTextFont;
    self.alertTitleLabel.textColor = self.alertTitleTextColor;
    self.alertTitleLabel.numberOfLines = 0;
    self.alertTitleLabel.textAlignment = NSTextAlignmentCenter;
    self.alertTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.alertView addSubview:self.alertTitleLabel];
    
    [self.alertView addConstraints:@[[NSLayoutConstraint constraintWithItem:self.alertTitleLabel
                                                                  attribute:NSLayoutAttributeTop
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.headerView
                                                                  attribute:NSLayoutAttributeBottom
                                                                 multiplier:1.0f
                                                                   constant:10.0f],
                                     [NSLayoutConstraint constraintWithItem:self.alertTitleLabel
                                                                  attribute:NSLayoutAttributeLeft
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertView
                                                                  attribute:NSLayoutAttributeLeft
                                                                 multiplier:1.0f
                                                                   constant:8.0f],
                                     [NSLayoutConstraint constraintWithItem:self.alertTitleLabel
                                                                  attribute:NSLayoutAttributeRight
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertView
                                                                  attribute:NSLayoutAttributeRight
                                                                 multiplier:1.0f
                                                                   constant:-8.0f]]];
    
    self.alertTitleLabelHeightConstraint = [NSLayoutConstraint constraintWithItem:self.alertTitleLabel
                                                                        attribute:NSLayoutAttributeHeight
                                                                        relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                           toItem:nil
                                                                        attribute:NSLayoutAttributeHeight
                                                                       multiplier:0.0f
                                                                         constant:0.0f];
    
    [self.alertView addConstraint:self.alertTitleLabelHeightConstraint];
    
}

- (void)_setUpAlertMessageLabel {
    
    self.alertMessageLabel = [[UILabel alloc] init];
    self.alertMessageLabel.font = self.alertMessageTextFont;
    self.alertMessageLabel.textColor = self.alertMessageTextColor;
    self.alertMessageLabel.numberOfLines = 0;
    self.alertMessageLabel.textAlignment = NSTextAlignmentCenter;
    self.alertMessageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.alertView addSubview:self.alertMessageLabel];
    
    [self.alertView addConstraints:@[[NSLayoutConstraint constraintWithItem:self.alertMessageLabel
                                                                  attribute:NSLayoutAttributeTop
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertTitleLabel
                                                                  attribute:NSLayoutAttributeBottom
                                                                 multiplier:1.0f
                                                                   constant:8.0f],
                                     [NSLayoutConstraint constraintWithItem:self.alertMessageLabel
                                                                  attribute:NSLayoutAttributeLeft
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertView
                                                                  attribute:NSLayoutAttributeLeft
                                                                 multiplier:1.0f
                                                                   constant:8.0f],
                                     [NSLayoutConstraint constraintWithItem:self.alertMessageLabel
                                                                  attribute:NSLayoutAttributeRight
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertView
                                                                  attribute:NSLayoutAttributeRight
                                                                 multiplier:1.0f
                                                                   constant:-8.0f],
                                     [NSLayoutConstraint constraintWithItem:self.alertMessageLabel
                                                                  attribute:NSLayoutAttributeHeight
                                                                  relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                     toItem:nil
                                                                  attribute:NSLayoutAttributeHeight
                                                                 multiplier:0.0f
                                                                   constant:0.0f]]];
    
}

- (void)_setUpAlertActionStackView {
    
    self.alertActionStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.alertActionStackView.distribution = UIStackViewDistributionFillEqually;
    self.alertActionStackView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.alertView addSubview:self.alertActionStackView];
    
    [self.alertView addConstraints:@[[NSLayoutConstraint constraintWithItem:self.alertActionStackView
                                                                  attribute:NSLayoutAttributeTop
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertMessageLabel
                                                                  attribute:NSLayoutAttributeBottom
                                                                 multiplier:1.0f
                                                                   constant:8.0f],
                                     [NSLayoutConstraint constraintWithItem:self.alertActionStackView
                                                                  attribute:NSLayoutAttributeRight
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertView
                                                                  attribute:NSLayoutAttributeRight
                                                                 multiplier:1.0f
                                                                   constant:0.0f],
                                     [NSLayoutConstraint constraintWithItem:self.alertActionStackView
                                                                  attribute:NSLayoutAttributeLeft
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertView
                                                                  attribute:NSLayoutAttributeLeft
                                                                 multiplier:1.0f
                                                                   constant:0.0f],
                                     [NSLayoutConstraint constraintWithItem:self.alertActionStackView
                                                                  attribute:NSLayoutAttributeBottom
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.alertView
                                                                  attribute:NSLayoutAttributeBottom
                                                                 multiplier:1.0f
                                                                   constant:0.0f]]];
    
    self.alertActionStackViewHeightConstraint = [NSLayoutConstraint constraintWithItem:self.alertActionStackView
                                                                             attribute:NSLayoutAttributeHeight
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:nil
                                                                             attribute:NSLayoutAttributeHeight
                                                                            multiplier:0.0f
                                                                              constant:60.0f];
    [self.alertView addConstraint:self.alertActionStackViewHeightConstraint];
    
}

- (void)_dismissAlertControllerFromAction:(VSAlertAction *)sender {
    
    // Pass action style to animator
    _dismissAnimator = [[VSAlertControllerTransitionAnimator alloc] initWithActionStyle:sender.style];
    [self dismissViewControllerAnimated:YES completion:nil];
    
}

- (void)_dismissAlertControllerFromBackgroundTap {
    
    // Pass "cancel" style to animator
    _dismissAnimator = [[VSAlertControllerTransitionAnimator alloc] initWithActionStyle:VSAlertActionStyleCancel];
    [self dismissViewControllerAnimated:YES completion:nil];
    
}

- (void)_addTextField:(UITextField *)textField {
    
    [self.alertActionStackView addArrangedSubview:textField];
    [self _configureStack];
    
}

- (void)_keyboardWillShow:(NSNotification *)notif {
    
    // Adjust alert view's location when keyboard appears
    
    _keyboardHasBeenShown = YES;
    
    NSDictionary *userInfo = notif.userInfo;
    double endKeyBoardFrame = CGRectGetMinY(((NSValue *)userInfo[UIKeyboardFrameEndUserInfoKey]).CGRectValue);
    
    if (_tempFrameOrigin.x == 0.0f && _tempFrameOrigin.y == 0.0f) {
        
        _tempFrameOrigin = self.alertView.frame.origin;
        
    }
    
    double newContentFrameY = CGRectGetMaxY(self.alertView.frame) - endKeyBoardFrame;
    
    if (newContentFrameY < 0.0f) {
        
        newContentFrameY = 0.0f;
        
    }
    
    self.alertView.frame = CGRectMake(self.alertView.frame.origin.x,
                                      self.alertView.frame.origin.y - newContentFrameY,
                                      self.alertView.frame.size.width,
                                      self.alertView.frame.size.height);
    
}

- (void)_keyboardWillHide:(NSNotification *)notif {
    
    // Adjust alert view's location when keyboard disappears
    
    if (_keyboardHasBeenShown) {
        
        if (_tempFrameOrigin.x != 0.0f || _tempFrameOrigin.y != 0.0f) {
            
            self.alertView.frame = CGRectMake(self.alertView.frame.origin.x,
                                              _tempFrameOrigin.y,
                                              self.alertView.frame.size.width,
                                              self.alertView.frame.size.height);
            
            _tempFrameOrigin = CGPointMake(0.0f, 0.0f);
            
        }
        
        _keyboardHasBeenShown = NO;
        
    }
    
}

- (void)_processTextFields {
    
    // Display Text Fields
    for (UITextField *textfield in self.textfields) {
        
        [self _addTextField:textfield];
        
    }
    
}

- (void)_processActions {
    
    if (_cancelActions.count > 1) {
        
        os_log_info(alert_log, "WARNING: Alerts with more than 1 ""Cancel"" action are not advisable");
        
    }
    
    NSInteger totalActions = _cancelActions.count + _destructiveActions.count + _defaultActions.count + self.textfields.count;
    
    if (totalActions > 2 || _style == VSAlertControllerStyleActionSheet) {
        
        [self _processDefaultActions];
        [self _processDestructiveActions];
        [self _processCancelActions];
        
    } else {
        
        [self _processCancelActions];
        [self _processDestructiveActions];
        [self _processDefaultActions];
        
    }
    
}

- (void)_processDefaultActions {
    
    for (VSAlertAction *alertAction in _defaultActions) {
        
        [self.alertActionStackView addArrangedSubview:alertAction];
        
        [alertAction addTarget:self
                        action:@selector(_tappedAction:)
              forControlEvents:UIControlEventTouchUpInside];
        
    }
    
    // Remove duplicate references
    _defaultActions = nil;
    
}

- (void)_processDestructiveActions {
    
    for (VSAlertAction *alertAction in _destructiveActions) {
        
        [self.alertActionStackView addArrangedSubview:alertAction];
        
        [alertAction addTarget:self
                        action:@selector(_tappedAction:)
              forControlEvents:UIControlEventTouchUpInside];
        
    }
    
    // Remove duplicate references
    _destructiveActions = nil;
    
}

- (void)_processCancelActions {
    
    for (VSAlertAction *alertAction in _cancelActions) {
        
        [self.alertActionStackView addArrangedSubview:alertAction];
        
        [alertAction addTarget:self
                        action:@selector(_tappedAction:)
              forControlEvents:UIControlEventTouchUpInside];
        
    }
    
    // Remove duplicate references
    _cancelActions = nil;
    
}

- (void)_configureStack {
    
    if (self.alertActionStackView.arrangedSubviews.count > 2 || self.hasTextFieldAdded || self.style == VSAlertControllerStyleActionSheet) {
        
        self.alertActionStackViewHeightConstraint.constant = self.alertStackViewHeight * ((CGFloat)self.alertActionStackView.arrangedSubviews.count);
        self.alertActionStackView.axis = UILayoutConstraintAxisVertical;
        
    } else {
        
        self.alertActionStackViewHeightConstraint.constant= self.alertStackViewHeight;
        self.alertActionStackView.axis = UILayoutConstraintAxisHorizontal;
        
    }
    
}

- (void)_tappedAction:(VSAlertAction *)sender {
    
    // Check for delegate and inform on main thread
    if ([self.delegate respondsToSelector:@selector(alertController:didSelectAction:)]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.delegate alertController:self
                           didSelectAction:sender];
            
        });
        
    }
    
    // Check if action has block and perform on main thread in-case of UI animations
    if (sender.action) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            sender.action(sender);
            
        });
        
    }
    
    [self _dismissAlertControllerFromAction:sender];
    
}

- (void)_closeKeyboard:(id)sender {
    
    [sender resignFirstResponder];
    
}

@end
