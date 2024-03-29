//
//  EditContactViewController.m
//  linphone
//
//  Created by Ei Captain on 4/4/17.
//
//

#import "EditContactViewController.h"
#import "TypePhoneObject.h"
#import "NewPhoneCell.h"
#import "InfoForNewContactTableCell.h"
#import "SettingItem.h"
#import "ChooseAvatarPopupView.h"
#import "NSData+Base64.h"
#import "ContactDetailObj.h"
#import "PECropViewController.h"
#import "TypePhonePopupView.h"
#import "PhoneObject.h"

#define ROW_CONTACT_NAME    0
#define ROW_CONTACT_EMAIL   1
#define ROW_CONTACT_COMPANY 2
#define NUMBER_ROW_BEFORE   3

@interface EditContactViewController ()<PECropViewControllerDelegate>
{
    AppDelegate *appDelegate;
    ChooseAvatarPopupView *popupChooseAvatar;
    PECropViewController *PECropController;
    
    UIView *viewFooter;
    UIButton *btnCancel;
    UIButton *btnSave;
    
    TypePhonePopupView *popupTypePhone;
}

@end

@implementation EditContactViewController
@synthesize _viewHeader, bgHeader, _iconBack, _lbHeader, tbContents, _imgAvatar, _imgChangePicture, _btnAvatar;
@synthesize detailsContact, idContact, curPhoneNumber;

#pragma mark - my controller

- (void)viewDidLoad {
    [super viewDidLoad];
    //  my code here
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [self setupUIForView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    self.navigationController.navigationBarHidden = TRUE;
    
    [self showContentWithCurrentLanguage];
    
    //  Get contact information
    if (detailsContact == nil) {
        detailsContact = [self getContactInPhoneBookWithIdRecord: idContact];
        
        if (curPhoneNumber != nil && ![curPhoneNumber isEqualToString:@""] && ![self checkCurrentPhone: curPhoneNumber inList: detailsContact._listPhone])
        {
            ContactDetailObj *aPhone = [[ContactDetailObj alloc] init];
            aPhone._iconStr = @"btn_contacts_mobile.png";
            aPhone._titleStr = [appDelegate.localization localizedStringForKey:type_phone_mobile];
            aPhone._valueStr = curPhoneNumber;
            aPhone._buttonStr = @"contact_detail_icon_call.png";
            aPhone._typePhone = type_phone_mobile;
            if (detailsContact._listPhone == nil){
                detailsContact._listPhone = [[NSMutableArray alloc] init];
            }
            [detailsContact._listPhone addObject: aPhone];
        }
    }
    [self displayContactInformation];
    
    [tbContents reloadData];
    if ([detailsContact._fullName isEqualToString:@""] || detailsContact._fullName == nil) {
        [self enableForSaveButton: NO];
    }else{
        [self enableForSaveButton: YES];
    }
    
    //  notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:)
                                                 name:UIKeyboardDidHideNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(whenSelectTypeForPhone:)
                                                 name:selectTypeForPhoneNumber object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear: animated];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)_iconBackClicked:(UIButton *)sender {
    detailsContact = nil;
    [self.navigationController popViewControllerAnimated: TRUE];
}

- (IBAction)_btnAvatarPressed:(UIButton *)sender {
    [self.view endEditing: YES];
    
    if (appDelegate.dataCrop != nil || (detailsContact._avatar != nil && ![detailsContact._avatar isEqualToString:@""])) {
        UIActionSheet *popupAddContact = [[UIActionSheet alloc] initWithTitle:[appDelegate.localization localizedStringForKey:@"Options"] delegate:self cancelButtonTitle:[appDelegate.localization localizedStringForKey:@"Cancel"] destructiveButtonTitle:nil otherButtonTitles:
                                          [appDelegate.localization localizedStringForKey:@"Gallery"],
                                          [appDelegate.localization localizedStringForKey:@"Camera"],
                                          [appDelegate.localization localizedStringForKey:@"Remove Avatar"],
                                          nil];
        popupAddContact.tag = 100;
        [popupAddContact showInView:self.view];
    }else{
        UIActionSheet *popupAddContact = [[UIActionSheet alloc] initWithTitle:[appDelegate.localization localizedStringForKey:@"Options"] delegate:self cancelButtonTitle:[appDelegate.localization localizedStringForKey:@"Cancel"] destructiveButtonTitle:nil otherButtonTitles:
                                          [appDelegate.localization localizedStringForKey:@"Gallery"],
                                          [appDelegate.localization localizedStringForKey:@"Camera"],
                                          nil];
        popupAddContact.tag = 101;
        [popupAddContact showInView:self.view];
    }
}

#pragma mark - my functions

- (ContactObject *)getContactInPhoneBookWithIdRecord: (int)idRecord
{
    ABAddressBookRef addressListBook = ABAddressBookCreate();
    ABRecordRef aPerson = ABAddressBookGetPersonWithRecordID(addressListBook, idRecord);
    
    ContactObject *aContact = [[ContactObject alloc] init];
    aContact.person = aPerson;
    aContact._id_contact = idRecord;
    aContact._fullName = [ContactsUtil getFullNameFromContact: aPerson];
    NSArray *nameInfo = [ContactsUtil getFirstNameAndLastNameOfContact: aPerson];
    aContact._firstName = [nameInfo objectAtIndex: 0];
    aContact._lastName = [nameInfo objectAtIndex: 1];
    
    if (![aContact._fullName isEqualToString:@""]) {
        NSString *convertName = [AppUtil convertUTF8CharacterToCharacter: aContact._fullName];
        aContact._nameForSearch = [AppUtil getNameForSearchOfConvertName: convertName];
    }
    
    //  Email
    aContact._email = [ContactsUtil getEmailFromContact: aPerson];
    
    ABMultiValueRef map = ABRecordCopyValue(aPerson, kABPersonEmailProperty);
    if (map) {
        for (int i = 0; i < ABMultiValueGetCount(map); ++i) {
            ABMultiValueIdentifier identifier = ABMultiValueGetIdentifierAtIndex(map, i);
            NSInteger index = ABMultiValueGetIndexForIdentifier(map, identifier);
            if (index != -1) {
                NSString *valueRef = CFBridgingRelease(ABMultiValueCopyValueAtIndex(map, index));
                if (valueRef != NULL && ![valueRef isEqualToString:@""]) {
                    //  just get one email for contact
                    aContact._email = valueRef;
                    break;
                }
            }
        }
        CFRelease(map);
    }
    
    //  Company
    CFStringRef companyRef  = ABRecordCopyValue(aPerson, kABPersonOrganizationProperty);
    if (companyRef != NULL && companyRef != nil){
        NSString *company = (__bridge NSString *)companyRef;
        if (company != nil && ![company isEqualToString:@""]){
            aContact._company = company;
        }
    }
    
    aContact._avatar = [ContactsUtil getBase64AvatarFromContact: aPerson];
    aContact._listPhone = [self getListPhoneOfContactPerson: aPerson withName: aContact._fullName];
    
    if (aContact._listPhone.count > 0) {
        ContactDetailObj *anItem = [aContact._listPhone firstObject];
        aContact._sipPhone = anItem._valueStr;
    }
    return aContact;
}

//  Chọn loại phone
- (void)whenSelectTypeForPhone: (NSNotification *)notif {
    id object = [notif object];
    if ([object isKindOfClass:[TypePhoneObject class]]) {
        int curIndex = (int)[popupTypePhone tag];
        
        //  Choose phone type for row: Add new phone
        NewPhoneCell *cell = [tbContents cellForRowAtIndexPath:[NSIndexPath indexPathForRow:curIndex inSection:0]];
        if ([cell isKindOfClass:[NewPhoneCell class]]) {
            NSString *imgName = [AppUtil getTypeOfPhone: [(TypePhoneObject *)object _strType]];
            [cell._iconTypePhone setBackgroundImage:[UIImage imageNamed:imgName]
                                           forState:UIControlStateNormal];
            [cell._iconTypePhone setTitle:[(TypePhoneObject *)object _strType] forState:UIControlStateNormal];
        }
        if (curIndex - NUMBER_ROW_BEFORE >= 0 && (curIndex - NUMBER_ROW_BEFORE) < detailsContact._listPhone.count)
        {
            ContactDetailObj *curPhone = [detailsContact._listPhone objectAtIndex: (curIndex - NUMBER_ROW_BEFORE)];
            curPhone._typePhone = [(TypePhoneObject *)object _strType];
            curPhone._iconStr = [AppUtil getTypeOfPhone: curPhone._typePhone];
            [tbContents reloadData];
        }
    }
}


- (void)whenTextfieldFullnameChanged: (UITextField *)textfield {
    //  Save fullname into first name
    detailsContact._fullName = textfield.text;
    
    if (![textfield.text isEqualToString:@""]) {
        [self enableForSaveButton: YES];
    }else{
        [self enableForSaveButton: NO];
    }
}

- (void)whenTextfieldChanged: (UITextField *)textfield {
    if (textfield.tag == 100) {
        detailsContact._email = textfield.text;
    }else if (textfield.tag == 101){
        detailsContact._company = textfield.text;
    }
}

- (void)enableForSaveButton: (BOOL)enable {
    btnSave.enabled = enable;
    if (enable) {
        btnSave.backgroundColor = [UIColor colorWithRed:(20/255.0) green:(129/255.0)
                                                   blue:(211/255.0) alpha:1.0];
    }else{
        btnSave.backgroundColor = [UIColor colorWithRed:(200/255.0) green:(200/255.0)
                                                   blue:(200/255.0) alpha:1.0];
    }
}

- (void)updateContactIntoAddressPhoneBook
{
    ABAddressBookRef addressBook;
    CFErrorRef anError = NULL;
    addressBook = ABAddressBookCreateWithOptions(nil, &anError);
    
    ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(addressBook, detailsContact._id_contact);
    
    // Lưu thông tin
    ABRecordSetValue(aRecord, kABPersonFirstNameProperty, (__bridge CFTypeRef)(detailsContact._fullName), &anError);
    ABRecordSetValue(aRecord, kABPersonLastNameProperty, (__bridge CFTypeRef)(detailsContact._lastName), &anError);
    ABRecordSetValue(aRecord, kABPersonOrganizationProperty, (__bridge CFTypeRef)(detailsContact._company), &anError);
    ABRecordSetValue(aRecord, kABPersonFirstNamePhoneticProperty, (__bridge CFTypeRef)(detailsContact._sipPhone), &anError);
    
    if (detailsContact._email != nil) {
        ABMutableMultiValueRef email = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(email, (__bridge CFTypeRef)(detailsContact._email), CFSTR("email"), NULL);
        ABRecordSetValue(aRecord, kABPersonEmailProperty, email, &anError);
    }
    
    if (appDelegate.dataCrop != nil) {
        CFDataRef cfdata = CFDataCreate(NULL,[appDelegate.dataCrop bytes], [appDelegate.dataCrop length]);
        ABPersonSetImageData(aRecord, cfdata, &anError);
    }
    
    // Phone number
    NSMutableArray *listPhone = [[NSMutableArray alloc] init];
    ABMutableMultiValueRef multiPhone = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    
    for (int iCount=0; iCount<detailsContact._listPhone.count; iCount++) {
        ContactDetailObj *aPhone = [detailsContact._listPhone objectAtIndex: iCount];
        if ([aPhone._typePhone isEqualToString: type_phone_mobile]) {
            ABMultiValueAddValueAndLabel(multiPhone, (__bridge CFTypeRef)(aPhone._valueStr), kABPersonPhoneMobileLabel, NULL);
            [listPhone addObject: aPhone];
        }else if ([aPhone._typePhone isEqualToString: type_phone_work]){
            ABMultiValueAddValueAndLabel(multiPhone, (__bridge CFTypeRef)(aPhone._valueStr), kABWorkLabel, NULL);
            [listPhone addObject: aPhone];
        }else if ([aPhone._typePhone isEqualToString: type_phone_fax]){
            ABMultiValueAddValueAndLabel(multiPhone, (__bridge CFTypeRef)(aPhone._valueStr), kABPersonPhoneHomeFAXLabel, NULL);
            [listPhone addObject: aPhone];
        }else if ([aPhone._typePhone isEqualToString: type_phone_home]){
            ABMultiValueAddValueAndLabel(multiPhone, (__bridge CFTypeRef)(aPhone._valueStr), kABHomeLabel, NULL);
            [listPhone addObject: aPhone];
        }
    }
    ABRecordSetValue(aRecord, kABPersonPhoneProperty, multiPhone,nil);
    CFRelease(multiPhone);
    
    //Address
    ABMutableMultiValueRef address = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
    NSMutableDictionary *addressDict = [[NSMutableDictionary alloc] init];
    [addressDict setObject:@"" forKey:(NSString *)kABPersonAddressStreetKey];
    [addressDict setObject:@"" forKey:(NSString *)kABPersonAddressZIPKey];
    [addressDict setObject:@"" forKey:(NSString *)kABPersonAddressStateKey];
    [addressDict setObject:@"" forKey:(NSString *)kABPersonAddressCityKey];
    [addressDict setObject:@"" forKey:(NSString *)kABPersonAddressCountryKey];
    ABMultiValueAddValueAndLabel(address, (__bridge CFTypeRef)(addressDict), kABWorkLabel, NULL);
    ABRecordSetValue(aRecord, kABPersonAddressProperty, address, &anError);
    
    if (anError != NULL) {
        NSLog(@"error while creating..");
    }
    
    anError = nil;
    BOOL isAdded = ABAddressBookAddRecord (addressBook,aRecord,&anError);
    
    if(isAdded){
        NSLog(@"added..");
    }
    if (anError != NULL) {
        NSLog(@"ABAddressBookAddRecord %@", anError);
    }
    anError = NULL;
    
    BOOL isSaved = ABAddressBookSave (addressBook,&anError);
    if(isSaved){
        NSLog(@"saved..");
    }
    
    if (anError != NULL) {
        NSLog(@"ABAddressBookSave %@", anError);
    }
    
    [self addNewContactToList: aRecord];
}

- (void)addNewContactToList: (ABRecordRef)aPerson
{
    ABMultiValueRef phones = ABRecordCopyValue(aPerson, kABPersonPhoneProperty);
    if (ABMultiValueGetCount(phones) > 0)
    {
        NSString *fullname = [ContactsUtil getFullNameFromContact: aPerson];
        NSString *convertName = [AppUtil convertUTF8CharacterToCharacter: fullname];
        NSString *nameForSearch = [AppUtil getNameForSearchOfConvertName: convertName];
        NSString *avatar = [ContactsUtil getBase64AvatarFromContact: aPerson];
        
        for(CFIndex j = 0; j < ABMultiValueGetCount(phones); j++)
        {
            CFStringRef phoneNumberRef = ABMultiValueCopyValueAtIndex(phones, j);
            NSString *phoneNumber = (__bridge NSString *)phoneNumberRef;
            phoneNumber = [AppUtil removeAllSpecialInString: phoneNumber];
            
            PhoneObject *phone = [[PhoneObject alloc] init];
            phone.number = phoneNumber;
            phone.name = fullname;
            phone.nameForSearch = nameForSearch;
            phone.avatar = avatar;
            phone.contactId = idContact;
            phone.phoneType = eNormalPhone;
            
            if (![appDelegate.listInfoPhoneNumber containsObject: phone]) {
                [appDelegate.listInfoPhoneNumber addObject: phone];
            }
        }
    }
}

- (void)showContentWithCurrentLanguage {
    _lbHeader.text = [appDelegate.localization localizedStringForKey:@"Edit contact"];
    [btnCancel setTitle:[appDelegate.localization localizedStringForKey:@"Cancel"]
               forState:UIControlStateNormal];
    [btnSave setTitle:[appDelegate.localization localizedStringForKey:@"Save"]
             forState:UIControlStateNormal];
}

//  Hiển thị thông tin của contact
- (void)displayContactInformation
{
    if (detailsContact._listPhone == nil) {
        detailsContact._listPhone = [[NSMutableArray alloc] init];
    }
    
    //  Avatar contact
    if (appDelegate.dataCrop != nil) {
        _imgAvatar.image = [UIImage imageWithData: appDelegate.dataCrop];
    }else{
        if (![AppUtil isNullOrEmpty: detailsContact._avatar]) {
            _imgAvatar.image = [UIImage imageWithData: [NSData base64DataFromString: detailsContact._avatar]];
        }else{
            _imgAvatar.image = [UIImage imageNamed:@"no_avatar.png"];
        }
    }
}

//  Chọn loại phone cho điện thoại
- (void)btnTypePhonePressed: (UIButton *)sender {
    [self.view endEditing: true];
    
    float hPopup;
    if (SCREEN_WIDTH > 320) {
        hPopup = 4*50 + 6;
    }else{
        hPopup = 4*40 + 6;
    }
    
    popupTypePhone = [[TypePhonePopupView alloc] initWithFrame:CGRectMake((SCREEN_WIDTH-236)/2, (SCREEN_HEIGHT-hPopup)/2, 236, hPopup)];
    [popupTypePhone setTag: sender.tag];
    [popupTypePhone showInView:appDelegate.window animated:YES];
}

//  Thêm hoặc xoá số phone
- (void)btnAddPhonePressed: (UIButton *)sender {
    int tag = (int)[sender tag];
    if (tag - NUMBER_ROW_BEFORE >= 0) {
        if ([sender.currentTitle isEqualToString:@"Add"])
        {
            NewPhoneCell *cell = [tbContents cellForRowAtIndexPath:[NSIndexPath indexPathForRow:tag inSection:0]];
            if (cell != nil && ![cell._tfPhone.text isEqualToString:@""]) {
                ContactDetailObj *aPhone = [[ContactDetailObj alloc] init];
                aPhone._valueStr = cell._tfPhone.text;
                aPhone._buttonStr = @"contact_detail_icon_call.png";
                
                NSString *type = cell._iconTypePhone.currentTitle;
                if ([type isEqualToString:type_phone_work])
                {
                    aPhone._typePhone = type_phone_work;
                    aPhone._iconStr = @"btn_contacts_work.png";
                    aPhone._titleStr = [appDelegate.localization localizedStringForKey:type_phone_work];
                    
                }else if ([type isEqualToString:type_phone_fax]){
                    aPhone._typePhone = type_phone_fax;
                    aPhone._iconStr = @"btn_contacts_fax.png";
                    aPhone._titleStr = [appDelegate.localization localizedStringForKey:type_phone_fax];
                    
                }else if ([type isEqualToString:type_phone_home]){
                    aPhone._typePhone = type_phone_home;
                    aPhone._iconStr = @"btn_contacts_home.png";
                    aPhone._titleStr = [appDelegate.localization localizedStringForKey:type_phone_home];
                    
                }else{
                    aPhone._typePhone = type_phone_mobile;
                    aPhone._iconStr = @"btn_contacts_mobile.png";
                    aPhone._titleStr = [appDelegate.localization localizedStringForKey:type_phone_mobile];
                }
                [detailsContact._listPhone addObject: aPhone];
            }else{
                [self.view makeToast:[appDelegate.localization localizedStringForKey:@"Please input phone number"]
                            duration:2.0 position:CSToastPositionCenter];
            }
        }else if ([sender.currentTitle isEqualToString:@"Remove"]){
            if (tag-NUMBER_ROW_BEFORE < detailsContact._listPhone.count) {
                [detailsContact._listPhone removeObjectAtIndex: tag-NUMBER_ROW_BEFORE];
            }
        }
    }
    
    //  Khi thêm mới hoặc xoá thì chỉ có dòng cuối cùng là new
    [tbContents reloadData];
}


- (void)whenTextfieldPhoneDidChanged: (UITextField *)textfield {
    int row = (int)[textfield tag];
    if ((row - NUMBER_ROW_BEFORE) < detailsContact._listPhone.count) {
        ContactDetailObj *curPhone = [detailsContact._listPhone objectAtIndex: (row - NUMBER_ROW_BEFORE)];
        [curPhone set_valueStr: textfield.text];
    }
}

//  Hiển thị bàn phím
- (void)keyboardWillShow: (NSNotification *) notif{
    CGSize keyboardSize = [[[notif userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    [tbContents mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.view).offset(-keyboardSize.height);
    }];
}

//  Ẩn bàn phím
- (void)keyboardDidHide: (NSNotification *) notif{
    [tbContents mas_updateConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.view);
    }];
}

- (void)setupUIForView {
    //  Tap vào màn hình để đóng bàn phím
    float wAvatar = 110.0;
    
    _lbHeader.font = appDelegate.fontLarge;
    
    UITapGestureRecognizer *tapOnScreen = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(whenTapOnMainScreen)];
    [self.view setUserInteractionEnabled: true];
    [self.view addGestureRecognizer: tapOnScreen];
    
    //  view header
    float hHeader = appDelegate.hStatus + appDelegate.hNav + wAvatar/2;
    [_viewHeader mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.height.mas_equalTo(hHeader);
    }];
    
    [bgHeader mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.bottom.right.equalTo(_viewHeader);
    }];
    
    [_lbHeader mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(_viewHeader).offset(appDelegate.hStatus);
        make.centerX.equalTo(_viewHeader.mas_centerX);
        make.width.mas_equalTo(200.0);
        make.height.mas_equalTo(appDelegate.hNav);
    }];
    
    _iconBack.imageEdgeInsets = UIEdgeInsetsMake(7, 7, 7, 7);
    [_iconBack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(_viewHeader);
        make.centerY.equalTo(_lbHeader.mas_centerY);
        make.width.height.mas_equalTo(40.0);
    }];
    
    _imgAvatar.layer.borderColor = UIColor.whiteColor.CGColor;
    _imgAvatar.layer.borderWidth = 2.0;
    _imgAvatar.image = [UIImage imageNamed:@"no_avatar.png"];
    _imgAvatar.layer.cornerRadius = wAvatar/2;
    _imgAvatar.clipsToBounds = YES;
    [_imgAvatar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view.mas_centerX);
        make.centerY.equalTo(_viewHeader.mas_bottom);
        make.width.height.mas_equalTo(wAvatar);
    }];
    
    [_btnAvatar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.bottom.right.equalTo(_imgAvatar);
    }];
    
    [_imgChangePicture mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(_imgAvatar.mas_centerX);
        make.bottom.equalTo(_imgAvatar.mas_bottom).offset(-10.0);
        make.width.height.mas_equalTo(20.0);
    }];
    
    [tbContents registerNib:[UINib nibWithNibName:@"InfoForNewContactTableCell" bundle:nil] forCellReuseIdentifier:@"InfoForNewContactTableCell"];
    [tbContents registerNib:[UINib nibWithNibName:@"NewPhoneCell" bundle:nil] forCellReuseIdentifier:@"NewPhoneCell"];
    tbContents.separatorStyle = UITableViewCellSeparatorStyleNone;
    tbContents.delegate = self;
    tbContents.dataSource = self;
    [tbContents mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(_viewHeader.mas_bottom);
        make.left.right.bottom.equalTo(self.view);
    }];
    
    UIView *viewHeader = [[UIView alloc] init];
    viewHeader.frame = CGRectMake(0, 0, SCREEN_WIDTH, wAvatar/2);
    viewHeader.backgroundColor = UIColor.clearColor;
    tbContents.tableHeaderView = viewHeader;
    
    //  Footer view
    viewFooter = [[UIView alloc] init];
    viewFooter.frame = CGRectMake(0, 0, SCREEN_WIDTH, 100);
    
    btnCancel = [[UIButton alloc] init];
    [btnCancel setTitle:[appDelegate.localization localizedStringForKey:@"Cancel"]
               forState:UIControlStateNormal];
    
    btnCancel.backgroundColor = [UIColor colorWithRed:(210/255.0) green:(51/255.0)
                                                 blue:(92/255.0) alpha:1.0];
    [btnCancel setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    btnCancel.clipsToBounds = YES;
    btnCancel.layer.cornerRadius = 40.0/2;
    [viewFooter addSubview: btnCancel];
    [btnCancel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(viewFooter.mas_centerX).offset(-10);
        make.centerY.equalTo(viewFooter.mas_centerY);
        make.width.mas_equalTo(140.0);
        make.height.mas_equalTo(40.0);
    }];
    
    btnSave = [[UIButton alloc] init];
    [btnSave setTitle:[appDelegate.localization localizedStringForKey:@"Save"]
             forState:UIControlStateNormal];
    btnSave.backgroundColor = [UIColor colorWithRed:(20/255.0) green:(129/255.0)
                                               blue:(211/255.0) alpha:1.0];
    [btnSave setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    btnSave.clipsToBounds = YES;
    btnSave.layer.cornerRadius = 40.0/2;
    [viewFooter addSubview: btnSave];
    [btnSave mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(viewFooter.mas_centerX).offset(10);
        make.centerY.equalTo(viewFooter.mas_centerY);
        make.width.equalTo(btnCancel.mas_width);
        make.height.equalTo(btnCancel.mas_height);
    }];
    [btnSave addTarget:self
                action:@selector(saveContactPressed:)
      forControlEvents:UIControlEventTouchUpInside];
    
    tbContents.tableFooterView = viewFooter;
}

//  Tap vào màn hình chính để đóng bàn phím
- (void)whenTapOnMainScreen {
    [self.view endEditing: true];
}

- (NSMutableArray *)getListPhoneOfContactPerson: (ABRecordRef)aPerson withName: (NSString *)contactName
{
    NSMutableArray *result = nil;
    ABMultiValueRef phones = ABRecordCopyValue(aPerson, kABPersonPhoneProperty);
    NSString *strPhone = [[NSMutableString alloc] init];
    if (ABMultiValueGetCount(phones) > 0)
    {
        result = [[NSMutableArray alloc] init];
        
        for(CFIndex j = 0; j < ABMultiValueGetCount(phones); j++)
        {
            CFStringRef phoneNumberRef = ABMultiValueCopyValueAtIndex(phones, j);
            CFStringRef locLabel = ABMultiValueCopyLabelAtIndex(phones, j);
            
            NSString *phoneNumber = (__bridge NSString *)phoneNumberRef;
            if (phoneNumber != nil) {
                phoneNumber = [AppUtil removeAllSpecialInString: phoneNumber];
            }
            
            strPhone = @"";
            if (locLabel == nil) {
                ContactDetailObj *anItem = [[ContactDetailObj alloc] init];
                anItem._iconStr = @"btn_contacts_home.png";
                anItem._titleStr = [appDelegate.localization localizedStringForKey:@"Home"];
                anItem._valueStr = phoneNumber;
                anItem._buttonStr = @"contact_detail_icon_call.png";
                anItem._typePhone = type_phone_home;
                [result addObject: anItem];
            }else{
                if (CFStringCompare(locLabel, kABHomeLabel, 0) == kCFCompareEqualTo) {
                    ContactDetailObj *anItem = [[ContactDetailObj alloc] init];
                    anItem._iconStr = @"btn_contacts_home.png";
                    anItem._titleStr = [appDelegate.localization localizedStringForKey:@"Home"];
                    anItem._valueStr = phoneNumber;
                    anItem._buttonStr = @"contact_detail_icon_call.png";
                    anItem._typePhone = type_phone_home;
                    [result addObject: anItem];
                }else if (CFStringCompare(locLabel, kABWorkLabel, 0) == kCFCompareEqualTo)
                {
                    ContactDetailObj *anItem = [[ContactDetailObj alloc] init];
                    anItem._iconStr = @"btn_contacts_work.png";
                    anItem._titleStr = [appDelegate.localization localizedStringForKey:@"Work"];
                    anItem._valueStr = phoneNumber;
                    anItem._buttonStr = @"contact_detail_icon_call.png";
                    anItem._typePhone = type_phone_work;
                    [result addObject: anItem];
                }else if (CFStringCompare(locLabel, kABPersonPhoneMobileLabel, 0) == kCFCompareEqualTo)
                {
                    ContactDetailObj *anItem = [[ContactDetailObj alloc] init];
                    anItem._iconStr = @"btn_contacts_mobile.png";
                    anItem._titleStr = [appDelegate.localization localizedStringForKey:@"Mobile"];
                    anItem._valueStr = phoneNumber;
                    anItem._buttonStr = @"contact_detail_icon_call.png";
                    anItem._typePhone = type_phone_mobile;
                    [result addObject: anItem];
                }else if (CFStringCompare(locLabel, kABPersonPhoneHomeFAXLabel, 0) == kCFCompareEqualTo)
                {
                    ContactDetailObj *anItem = [[ContactDetailObj alloc] init];
                    anItem._iconStr = @"btn_contacts_fax.png";
                    anItem._titleStr = [appDelegate.localization localizedStringForKey:@"Fax"];
                    anItem._valueStr = phoneNumber;
                    anItem._buttonStr = @"contact_detail_icon_call.png";
                    anItem._typePhone = type_phone_fax;
                    [result addObject: anItem];
                }else if (CFStringCompare(locLabel, kABOtherLabel, 0) == kCFCompareEqualTo)
                {
                    ContactDetailObj *anItem = [[ContactDetailObj alloc] init];
                    anItem._iconStr = @"btn_contacts_fax.png";
                    anItem._titleStr = [appDelegate.localization localizedStringForKey:@"Other"];
                    anItem._valueStr = phoneNumber;
                    anItem._buttonStr = @"contact_detail_icon_call.png";
                    anItem._typePhone = type_phone_other;
                    [result addObject: anItem];
                }else{
                    ContactDetailObj *anItem = [[ContactDetailObj alloc] init];
                    anItem._iconStr = @"btn_contacts_mobile.png";
                    anItem._titleStr = [appDelegate.localization localizedStringForKey:@"Mobile"];
                    anItem._valueStr = phoneNumber;
                    anItem._buttonStr = @"contact_detail_icon_call.png";
                    anItem._typePhone = type_phone_mobile;
                    [result addObject: anItem];
                }
            }
        }
    }
    return result;
}

- (void)saveContactPressed: (UIButton *)sender {
    [self.view endEditing: TRUE];
    
    [ProgressHUD backgroundColor: ProgressHUD_BG];
    [ProgressHUD show:[appDelegate.localization localizedStringForKey:@"Please wait..."] Interaction:NO];
    
    [self updateContactIntoAddressPhoneBook];
    [appDelegate fetchAllContactsFromPhoneBook];

    [self performSelector:@selector(hideWaitingView) withObject:nil afterDelay:1.0];
}

- (void)hideWaitingView {
    [ProgressHUD dismiss];
    [self.navigationController popViewControllerAnimated: TRUE];
}

#pragma mark - Picker image

- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo
{
    [appDelegate enableSizeForBarButtonItem: FALSE];
    
    // Crop image trong edits contact
    appDelegate.cropAvatar = image;
    
    [picker dismissViewControllerAnimated:YES completion:^{
        [self openEditor];
    }];
}

- (void)openEditor {
    PECropController = [[PECropViewController alloc] init];
    PECropController.delegate = self;
    PECropController.image = appDelegate.cropAvatar;
    
    UIImage *image = appDelegate.cropAvatar;
    CGFloat width = image.size.width;
    CGFloat height = image.size.height;
    CGFloat length = MIN(width, height);
    PECropController.imageCropRect = CGRectMake((width - length) / 2,
                                                (height - length) / 2,
                                                length, length);
    PECropController.keepingCropAspectRatio = true;
    
    [self.navigationController pushViewController:PECropController animated:TRUE];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [appDelegate enableSizeForBarButtonItem: FALSE];
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UITableview Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return NUMBER_ROW_BEFORE + [detailsContact._listPhone count] + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == ROW_CONTACT_NAME || indexPath.row == ROW_CONTACT_EMAIL || indexPath.row == ROW_CONTACT_COMPANY)
    {
        InfoForNewContactTableCell *cell = [tableView dequeueReusableCellWithIdentifier: @"InfoForNewContactTableCell"];
        switch (indexPath.row) {
                case ROW_CONTACT_NAME:{
                    cell.lbTitle.text = [appDelegate.localization localizedStringForKey:@"Fullname"];
                    cell.tfContent.text = detailsContact._fullName;
                    [cell.tfContent addTarget:self
                                       action:@selector(whenTextfieldFullnameChanged:)
                             forControlEvents:UIControlEventEditingChanged];
                    break;
                }
                case ROW_CONTACT_EMAIL:{
                    cell.lbTitle.text = [appDelegate.localization localizedStringForKey:@"Email"];
                    cell.tfContent.tag = 100;
                    cell.tfContent.text = detailsContact._email;
                    cell.tfContent.keyboardType = UIKeyboardTypeEmailAddress;
                    [cell.tfContent addTarget:self
                                       action:@selector(whenTextfieldChanged:)
                             forControlEvents:UIControlEventEditingChanged];
                    break;
                }
                case ROW_CONTACT_COMPANY:{
                    cell.lbTitle.text = [appDelegate.localization localizedStringForKey:@"Company"];
                    cell.tfContent.tag = 101;
                    cell.tfContent.text = detailsContact._company;
                    [cell.tfContent addTarget:self
                                       action:@selector(whenTextfieldChanged:)
                             forControlEvents:UIControlEventEditingChanged];
                    break;
                }
        }
        return cell;
    }else
    {
        NewPhoneCell *cell = [tableView dequeueReusableCellWithIdentifier: @"NewPhoneCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        if (indexPath.row == detailsContact._listPhone.count + NUMBER_ROW_BEFORE) {
            cell._tfPhone.text = @"";
            
            [cell._iconNewPhone setTitle:@"Add" forState:UIControlStateNormal];
            [cell._iconNewPhone setBackgroundImage:[UIImage imageNamed:@"ic_add_phone.png"]
                                          forState:UIControlStateNormal];
        }else{
            if ((indexPath.row - NUMBER_ROW_BEFORE) >= 0 && (indexPath.row - NUMBER_ROW_BEFORE) < detailsContact._listPhone.count) {
                ContactDetailObj *aPhone = [detailsContact._listPhone objectAtIndex: (indexPath.row - NUMBER_ROW_BEFORE)];
                cell._tfPhone.text = aPhone._valueStr;
                
                [cell._iconNewPhone setTitle:@"Remove" forState:UIControlStateNormal];
                [cell._iconNewPhone setBackgroundImage:[UIImage imageNamed:@"ic_delete_phone.png"]
                                              forState:UIControlStateNormal];
                
                [cell._iconTypePhone setTitle:aPhone._typePhone forState:UIControlStateNormal];
                [cell._iconTypePhone setBackgroundImage:[UIImage imageNamed:aPhone._iconStr]
                                               forState:UIControlStateNormal];
            }
        }
        cell._tfPhone.tag = indexPath.row;
        [cell._tfPhone addTarget:self
                          action:@selector(whenTextfieldPhoneDidChanged:)
                forControlEvents:UIControlEventEditingChanged];
        
        cell._iconNewPhone.tag = indexPath.row;
        [cell._iconNewPhone addTarget:self
                               action:@selector(btnAddPhonePressed:)
                     forControlEvents:UIControlEventTouchUpInside];
        
        cell._iconTypePhone.tag = indexPath.row;
        [cell._iconTypePhone addTarget:self
                                action:@selector(btnTypePhonePressed:)
                      forControlEvents:UIControlEventTouchUpInside];
        
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == ROW_CONTACT_NAME || indexPath.row == ROW_CONTACT_EMAIL || indexPath.row == ROW_CONTACT_COMPANY) {
        return 83.0;
    }
    return 50.0;
}

#pragma mark - PECropViewControllerDelegate methods

- (void)cropViewController:(PECropViewController *)controller didFinishCroppingImage:(UIImage *)croppedImage transform:(CGAffineTransform)transform cropRect:(CGRect)cropRect
{
    [controller dismissViewControllerAnimated:YES completion:NULL];
    appDelegate.dataCrop = UIImagePNGRepresentation(croppedImage);
}

- (void)cropViewControllerDidCancel:(PECropViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - ActionSheet Delegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 100) {
        switch (buttonIndex) {
                case 0:{
                    [self pressOnGallery];
                    break;
                }
                case 1:{
                    [self pressOnCamera];
                    break;
                }
                case 2:{
                    [self removeAvatar];
                    break;
                }
                case 3:{
                    NSLog(@"Cancel");
                    break;
                }
        }
    }else if (actionSheet.tag == 101){
        switch (buttonIndex) {
                case 0:{
                    [self pressOnGallery];
                    break;
                }
                case 1:{
                    [self pressOnCamera];
                    break;
                }
        }
    }
}

- (void)pressOnCamera {
    appDelegate.fromImagePicker = YES;
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    [picker setDelegate: self];
    [picker setSourceType: UIImagePickerControllerSourceTypeCamera];
    [self presentViewController:picker animated:YES completion:NULL];
}

- (void)pressOnGallery {
    appDelegate.fromImagePicker = YES;
    [appDelegate enableSizeForBarButtonItem: TRUE];
    
    UIImagePickerController *pickerController = [[UIImagePickerController alloc] init];
    pickerController.delegate = self;
    [self presentViewController:pickerController animated:YES completion:nil];
}

- (void)removeAvatar {
    if (appDelegate.dataCrop != nil) {
        appDelegate.dataCrop = nil;
        if (detailsContact._avatar != nil && ![detailsContact._avatar isEqualToString:@""]){
            _imgAvatar.image = [UIImage imageWithData: [NSData base64DataFromString: detailsContact._avatar]];
        }else{
            _imgAvatar.image = [UIImage imageNamed:@"no_avatar.png"];
        }
    }else{
        detailsContact._avatar = @"";
        _imgAvatar.image = [UIImage imageNamed:@"no_avatar.png"];
    }
}

- (BOOL)checkCurrentPhone: (NSString *)phone inList: (NSArray *)listPhone {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"_valueStr = %@", phone];
    NSArray *filter = [listPhone filteredArrayUsingPredicate: predicate];
    if (filter.count > 0) {
        return YES;
    }
    return NO;
}

@end
