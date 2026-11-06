/**
 * Test data builders for PeopleSphere tests.
 */
@IsTest
public class PS_TestFactory {

    public class World {
        public Organization__c org;
        public Department__c eng;
        public Department__c hr;
        public Location__c loc;
        public Designation__c dev;
        public Designation__c lead;
        public Employee__c manager;   // linked to the running user
        public Employee__c employee;  // reports to manager
    }

    public static World world() {
        World w = new World();
        w.org = new Organization__c(Name = 'Test Corp', Employee_ID_Prefix__c = 'TST', Default_Notice_Period_Days__c = 30, Country__c = 'India');
        insert w.org;
        w.eng = new Department__c(Name = 'Engineering', Organization__c = w.org.Id, Code__c = 'ENG', Active__c = true);
        w.hr = new Department__c(Name = 'Human Resources', Organization__c = w.org.Id, Code__c = 'HR', Active__c = true);
        insert new List<Department__c>{ w.eng, w.hr };
        w.loc = new Location__c(Name = 'Hyderabad', Organization__c = w.org.Id, City__c = 'Hyderabad', Office_Start_Time__c = '09:30', Late_Grace_Minutes__c = 15);
        insert w.loc;
        w.dev = new Designation__c(Name = 'Software Engineer', Level__c = 2, Grade__c = 'L2', Organization__c = w.org.Id, Required_Skills__c = 'apex;lwc');
        w.lead = new Designation__c(Name = 'Tech Lead', Level__c = 4, Grade__c = 'L4', Organization__c = w.org.Id);
        insert new List<Designation__c>{ w.dev, w.lead };
        w.manager = employee(w, 'Maya', 'Manager', 'Active', null);
        w.manager.User__c = UserInfo.getUserId();
        w.manager.Designation__c = w.lead.Id;
        insert w.manager;
        w.employee = employee(w, 'Eli', 'Engineer', 'Active', w.manager.Id);
        insert w.employee;
        return w;
    }

    public static Employee__c employee(World w, String first, String last, String status, Id managerId) {
        return new Employee__c(Name = first + ' ' + last, First_Name__c = first, Last_Name__c = last,
            Work_Email__c = first.toLowerCase() + '.' + last.toLowerCase() + Crypto.getRandomInteger() + '@example.com',
            Organization__c = w.org.Id, Department__c = w.eng.Id, Location__c = w.loc.Id, Designation__c = w.dev.Id,
            Manager__c = managerId, Status__c = status, Date_of_Joining__c = Date.today().addYears(-2),
            Date_of_Birth__c = Date.today().addYears(-30), Skills__c = 'Apex;Java', Annual_CTC__c = 1200000,
            Employment_Type__c = 'Full-time', Work_Mode__c = 'Hybrid');
    }

    public static Learning_Course__c course(String name, Boolean mandatory, Decimal validityMonths) {
        return new Learning_Course__c(Name = name, Course_Code__c = name.left(10).replaceAll(' ', '') + Crypto.getRandomInteger(),
            Category__c = 'Compliance', Mandatory__c = mandatory, Active__c = true, Passing_Score__c = 50,
            Certification_Validity_Months__c = validityMonths, Due_In_Days__c = 30, Skills_Covered__c = 'lwc;security');
    }

    /** A Monday at least a week in the future, so leave tests never hit weekends. */
    public static Date nextMonday() {
        Date d = Date.today().addDays(7);
        while (Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('E') != 'Mon') d = d.addDays(1);
        return d;
    }
}
