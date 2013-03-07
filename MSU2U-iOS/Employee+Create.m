//
//  Employee+Create.m
//  MSU2U-iOS
//
//  Created by Matthew Farmer on 11/15/12.
//  Copyright (c) 2012 Matthew Farmer. All rights reserved.
//

#import "Employee+Create.h"

@implementation Employee (Create)

+(Employee *)employeeWithInfo:(NSDictionary*)info inManagedObjectContext:(NSManagedObjectContext*)context
{
    Employee * employee = nil;
    
    NSFetchRequest * request = [NSFetchRequest fetchRequestWithEntityName:@"Employee"];
    
    //How do I uniquely identify this employee?
    request.predicate = [NSPredicate predicateWithFormat:@"person_id = %@", [info objectForKey:@"Person_ID"]];
    NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"lname" ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    
    NSError * error = nil;
    NSArray * employees = [context executeFetchRequest:request error:&error];
    
    if(!employees || ([employees count] > 1))
    {
        //handle error
    }
    else if(![employees count])
    {
        //Let's see if I want this new item or not
        if([[info objectForKey:@"LName"] length] == 0)
        {
            NSLog(@"I REFUSED TO LOAD AN EMPLOYEE with the first name %@ because there was no last name provided...\n",[info objectForKey:@"FName"]);
            //This person doesn't have a last name, so this person is not suitable to be inserted into database
            //do nothing
        }
        else
        {
            employee = [NSEntityDescription insertNewObjectForEntityForName:@"Employee" inManagedObjectContext:context];
            
            //These attributes are received from the server
            employee.person_id = [info objectForKey:@"Person_ID"];
            employee.last_changed = [info objectForKey:@"last_changed"];
            employee.deleted = [info objectForKey:@"deleted"];
            employee.position_title_1 = [info objectForKey:@"Position_1"];
            employee.position_title_2 = [info objectForKey:@"Position_2"];
            employee.name_prefix = [info objectForKey:@"Name_Prefix"];
            employee.fname = [info objectForKey:@"FName"];
            employee.middle = [info objectForKey:@"Middle"];
            employee.lname = [info objectForKey:@"LName"];
            employee.email = [info objectForKey:@"Email"];
            employee.dept_id_1 = [info objectForKey:@"Dept_1"];
            employee.dept_id_2 = [info objectForKey:@"Dept_2"];
            employee.office_bldg_id_1 = [info objectForKey:@"Office_Bldg_1"];
            employee.office_bldg_id_2 = [info objectForKey:@"Office_Bldg_2"];
            employee.office_rm_num_1 = [info objectForKey:@"Office_Rm_Num_1"];
            employee.office_rm_num_2 = [info objectForKey:@"Office_Rm_Num_2"];
            
            //I need to make sure these guys aren't bad numbers
            if([[info objectForKey:@"Phone1"] length]<12)
                employee.phone1 = @"";
            else
                employee.phone1 = [info objectForKey:@"Phone1"];
            
            if([[info objectForKey:@"Fax1"] length]<12)
                employee.fax1 = @"";
            else
                employee.fax1 = [info objectForKey:@"Fax1"];
            
            if([[info objectForKey:@"Phone2"] length]<12)
                employee.phone2 = @"";
            else
                employee.phone2 = [info objectForKey:@"Phone2"];
            
            if([[info objectForKey:@"Fax2"] length]<12)
                employee.fax2 = @"";
            else
                employee.fax2 = [info objectForKey:@"Fax2"];
                
            //If two phone numbers, fax numbers, office numbers, etc. are the same, I will suppress the second by making it == ""
            if([employee.phone1 isEqualToString:employee.phone2])
                employee.phone2 = @"";
            if([employee.fax1 isEqualToString:employee.fax2])
                employee.fax2 =  @"";
            if([employee.position_title_1 isEqualToString:employee.position_title_2])
                employee.position_title_2 = @"";
            if([employee.office_bldg_id_1 isEqualToString:employee.office_bldg_id_2] && [employee.office_rm_num_1 isEqualToString:employee.office_rm_num_2])
            {
                employee.office_bldg_id_2 = @"";
                employee.office_rm_num_2 = @"";
            }
            if([employee.dept_id_1 isEqualToString:employee.dept_id_2])
                employee.dept_id_2 = @"";
            
            
            employee.link_to_more_info = [info objectForKey:@"Link_To_More_Info"];
            employee.picture = [info objectForKey:@"Picture"];
            
            //These are attributes I'm interested in on the iOS side, thus will not be found from the server
            employee.favorite = @"no";
            employee.history = nil;
        }
    }
    else
    {
        employee = [employees lastObject];
    }
    
    return employee;
}

@end
