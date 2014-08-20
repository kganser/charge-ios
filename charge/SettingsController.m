#import "SettingsController.h"
#import "AppDelegate.h"
#import "MMDrawerController.h"
#import "MapController.h"

@implementation SettingsController {
    NSArray *options;
    NSUserDefaults *prefs;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.delegate = self;
    options = @[@"chargepoint", @"blink", @"level1", @"level2", @"level3", @"unavailable", @"favorites"];
    prefs = [AppDelegate getPreferences];
}

- (void)viewDidLayoutSubviews {
    int i = 0;
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        if ([prefs boolForKey:[options objectAtIndex:i]])
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.tag = i++;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.textLabel.textColor = [UIColor whiteColor];
    header.backgroundView.backgroundColor = [UIColor colorWithRed:92.f/256 green:97.f/256 blue:101.f/256 alpha:1.f];
}

- (void)viewWillDisappear:(BOOL)animated {
    [(MapController *)[((MMDrawerController *)self.parentViewController.parentViewController).centerViewController.childViewControllers objectAtIndex:0] updateMarkers];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *option = [options objectAtIndex:cell.tag];
    BOOL value = [prefs boolForKey:option];
    cell.accessoryType = value ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
    [prefs setBool:!value forKey:option];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
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
