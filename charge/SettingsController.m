#import "SettingsController.h"

@interface SettingsController ()
@property (weak, nonatomic) IBOutlet UITableViewCell *optChargepoint;
@property (weak, nonatomic) IBOutlet UITableViewCell *optBlink;
@property (weak, nonatomic) IBOutlet UITableViewCell *optLevel1;
@property (weak, nonatomic) IBOutlet UITableViewCell *optLevel2;
@property (weak, nonatomic) IBOutlet UITableViewCell *optLevel3;
@property (weak, nonatomic) IBOutlet UITableViewCell *optUnavailable;
@property (weak, nonatomic) IBOutlet UITableViewCell *optFavorites;
@end

@implementation SettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    static NSMutableDictionary *preferences = nil;
    if (preferences == nil)
        preferences = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@YES, @"optChargepoint", @YES, @"optBlink", @YES, @"optLevel1", @YES, @"optLevel2", @NO, @"optLevel3", @YES, @"optUnavailable", @NO, @"optFavorites", nil];
    for (id option in preferences) {
        UISwitch *button = [[UISwitch alloc] init];
        [button setOn:[[preferences objectForKey:option] boolValue]];
        [button addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];
        [[self valueForKey:option] setAccessoryView:button];
    }
}

- (void)toggle:(id)sender {
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
