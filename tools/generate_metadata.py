"""
PeopleSphere metadata generator.

Generates custom objects, fields, list views, page layouts, tabs and permission
sets from the compact schema in this file. Re-run after editing the schema:

    python tools/generate_metadata.py

Apex, LWC, flexipages and the app are hand-written and are not touched.
"""
import os
import shutil
from xml.sax.saxutils import escape

ROOT = os.path.join(os.path.dirname(__file__), "..", "force-app", "main", "default")
NS = 'xmlns="http://soap.sforce.com/2006/04/metadata"'
HEAD = '<?xml version="1.0" encoding="UTF-8"?>\n'


# ----------------------------------------------------------------------------
# Field helpers
# ----------------------------------------------------------------------------
def T(api, label, length=255, req=False, unique=False, ext=False, help=None):
    return dict(api=api, label=label, type="Text", length=length, req=req, unique=unique, ext=ext, help=help)

def LT(api, label, length=32768, lines=4, help=None):
    return dict(api=api, label=label, type="LongTextArea", length=length, lines=lines, help=help)

def N(api, label, precision=18, scale=0, default=None, help=None):
    return dict(api=api, label=label, type="Number", precision=precision, scale=scale, default=default, help=help)

def CUR(api, label, help=None):
    return dict(api=api, label=label, type="Currency", precision=16, scale=2, help=help)

def PCT(api, label):
    return dict(api=api, label=label, type="Percent", precision=5, scale=2)

def D(api, label, req=False):
    return dict(api=api, label=label, type="Date", req=req)

def DT(api, label):
    return dict(api=api, label=label, type="DateTime")

def CB(api, label, default=False, help=None):
    return dict(api=api, label=label, type="Checkbox", default=default, help=help)

def EM(api, label):
    return dict(api=api, label=label, type="Email")

def PH(api, label):
    return dict(api=api, label=label, type="Phone")

def URL(api, label):
    return dict(api=api, label=label, type="Url")

def PL(api, label, values, default=None, req=False, help=None):
    return dict(api=api, label=label, type="Picklist", values=values, default=default, req=req, help=help)

def LK(api, label, ref, rel, rel_label=None, req=False):
    return dict(api=api, label=label, type="Lookup", ref=ref, rel=rel, rel_label=rel_label or rel.replace("_", " "), req=req)

def MD(api, label, ref, rel, rel_label=None):
    return dict(api=api, label=label, type="MasterDetail", ref=ref, rel=rel, rel_label=rel_label or rel.replace("_", " "))

def F(api, label, ftype, formula, scale=0, blank_zero=True):
    return dict(api=api, label=label, type="Formula", ftype=ftype, formula=formula, scale=scale, blank_zero=blank_zero)

def RS(api, label, op, child, fk, field=None, filters=None):
    return dict(api=api, label=label, type="Summary", op=op, child=child, fk=fk, field=field, filters=filters or [])


# Shared value sets ---------------------------------------------------------
TEAMS = ["HR", "IT", "Finance", "Manager", "Employee", "Learning", "Facilities", "Department"]
TASK_STATUS = ["Not Started", "In Progress", "Completed", "Blocked", "Skipped"]
TASK_CATEGORY = ["Documentation", "Equipment", "Access", "Training", "Orientation", "Compliance",
                 "Clearance", "Knowledge Transfer", "Settlement"]
EMP_TYPES = ["Full-time", "Part-time", "Contractor", "Intern", "Consultant", "Vendor"]
WORK_MODES = ["Office", "Hybrid", "Remote"]
PRIORITY = ["Low", "Medium", "High", "Critical"]


def OBJ(api, label, plural, name=("Text", None, None), sharing="ReadWrite", history=False,
        desc="", fields=(), icon="Custom19: Wrench", list_cols=None, tab=True):
    return dict(api=api, label=label, plural=plural, name=name, sharing=sharing, history=history,
                desc=desc, fields=list(fields), icon=icon, list_cols=list_cols or [], tab=tab)


def task_fields(rel_user):
    return [
        PL("Assigned_Team__c", "Assigned Team", TEAMS, default="HR"),
        LK("Assigned_To__c", "Assigned To", "User", rel_user),
        D("Due_Date__c", "Due Date"),
        PL("Status__c", "Status", TASK_STATUS, default="Not Started"),
        CB("Mandatory__c", "Mandatory", True),
        N("Sequence__c", "Sequence", 4, 0),
        PL("Category__c", "Category", TASK_CATEGORY),
        LT("Description__c", "Description", 5000),
        DT("Completed_On__c", "Completed On"),
        F("Is_Overdue__c", "Overdue", "Checkbox",
          "AND(NOT(ISPICKVAL(Status__c,'Completed')), NOT(ISPICKVAL(Status__c,'Skipped')), NOT(ISBLANK(Due_Date__c)), Due_Date__c < TODAY())"),
    ]


# ----------------------------------------------------------------------------
# Schema
# ----------------------------------------------------------------------------
SCHEMA = [
    # ---------------- Organization & administration -----------------------
    OBJ("Organization__c", "Organization", "Organizations", ("Text", "Organization Name", None),
        desc="Customer organization / legal entity (tenant boundary).", icon="Custom57: Building",
        list_cols=["Country__c", "Industry__c", "Active__c"], fields=[
            T("Legal_Entity_Name__c", "Legal Entity Name"),
            T("Country__c", "Country", 80),
            T("Headquarters__c", "Headquarters"),
            PL("Industry__c", "Industry", ["Technology", "Manufacturing", "Healthcare", "Financial Services",
                                           "Retail", "Education", "Professional Services", "Other"]),
            T("Employee_ID_Prefix__c", "Employee ID Prefix", 10, help="Prefix used for generated employee IDs, e.g. PS"),
            URL("Logo_URL__c", "Logo URL"),
            T("Brand_Color__c", "Brand Color", 7, help="Hex color, e.g. #0B5CAB"),
            N("Default_Notice_Period_Days__c", "Default Notice Period (Days)", 3, 0, default=60),
            N("Standard_Work_Hours__c", "Standard Work Hours / Day", 3, 1, default=9),
            CB("Active__c", "Active", True),
        ]),
    OBJ("Business_Unit__c", "Business Unit", "Business Units", icon="Custom57: Building",
        list_cols=["Organization__c", "Code__c"], fields=[
            LK("Organization__c", "Organization", "Organization__c", "Business_Units"),
            T("Code__c", "Code", 20),
            LK("Head__c", "Business Unit Head", "Employee__c", "Business_Units_Headed"),
            LT("Description__c", "Description", 5000),
        ]),
    OBJ("Department__c", "Department", "Departments", icon="Custom57: Building",
        list_cols=["Code__c", "Organization__c", "Department_Head__c", "Active__c"], fields=[
            LK("Organization__c", "Organization", "Organization__c", "Departments"),
            LK("Business_Unit__c", "Business Unit", "Business_Unit__c", "Departments"),
            T("Code__c", "Code", 20),
            T("Cost_Center__c", "Cost Center", 40),
            LK("Department_Head__c", "Department Head", "Employee__c", "Departments_Headed"),
            N("Headcount_Budget__c", "Headcount Budget", 6, 0),
            CB("Active__c", "Active", True),
        ]),
    OBJ("Location__c", "Location", "Locations", icon="Custom64: Map",
        list_cols=["City__c", "Country__c", "Organization__c"], fields=[
            LK("Organization__c", "Organization", "Organization__c", "Locations"),
            T("City__c", "City", 80),
            T("State__c", "State / Province", 80),
            T("Country__c", "Country", 80),
            T("Address__c", "Address"),
            T("Time_Zone__c", "Time Zone", 60),
            T("Office_Start_Time__c", "Office Start Time", 5, help="24h HH:MM. Check-ins after this + grace are marked late."),
            N("Late_Grace_Minutes__c", "Late Grace (Minutes)", 3, 0, default=15),
            CB("Active__c", "Active", True),
        ]),
    OBJ("Designation__c", "Designation", "Designations", icon="Custom44: Award",
        list_cols=["Grade__c", "Level__c", "Department__c"], fields=[
            LK("Organization__c", "Organization", "Organization__c", "Designations"),
            LK("Department__c", "Department", "Department__c", "Designations"),
            PL("Grade__c", "Grade", ["L1", "L2", "L3", "L4", "L5", "L6", "L7", "L8", "Executive"]),
            N("Level__c", "Level", 2, 0),
            T("Job_Family__c", "Job Family", 80),
            T("Required_Skills__c", "Required Skills", 255, help="Semicolon separated. Used for skill-gap analysis."),
            LT("Description__c", "Description", 5000),
        ]),

    # ---------------- Employee 360 ----------------------------------------
    OBJ("Employee__c", "Employee", "Employees", ("Text", "Full Name", None), sharing="Private", history=True,
        desc="Employee master record - the centre of the employee lifecycle.", icon="Custom15: Children at play",
        list_cols=["Employee_ID__c", "Department__c", "Designation__c", "Manager__c", "Status__c"], fields=[
            T("Employee_ID__c", "Employee ID", 30, unique=True, ext=True, help="Generated automatically."),
            T("First_Name__c", "First Name", 80),
            T("Last_Name__c", "Last Name", 80),
            EM("Work_Email__c", "Work Email"),
            EM("Personal_Email__c", "Personal Email"),
            PH("Phone__c", "Phone"),
            URL("Photo_URL__c", "Photo URL"),
            LK("Organization__c", "Organization", "Organization__c", "Employees"),
            LK("Business_Unit__c", "Business Unit", "Business_Unit__c", "Employees"),
            LK("Department__c", "Department", "Department__c", "Employees"),
            LK("Designation__c", "Designation", "Designation__c", "Employees"),
            LK("Location__c", "Location", "Location__c", "Employees"),
            LK("Manager__c", "Reporting Manager", "Employee__c", "Direct_Reports"),
            LK("User__c", "Salesforce User", "User", "PS_Employees", "PeopleSphere Employees"),
            PL("Status__c", "Status", ["Pre-boarding", "Onboarding", "Active", "On Notice", "Exited", "Alumni"], default="Pre-boarding"),
            PL("Employment_Type__c", "Employment Type", EMP_TYPES, default="Full-time"),
            PL("Work_Mode__c", "Work Mode", WORK_MODES, default="Office"),
            D("Date_of_Joining__c", "Date of Joining"),
            D("Confirmation_Date__c", "Confirmation Date"),
            D("Date_of_Birth__c", "Date of Birth"),
            D("Exit_Date__c", "Exit Date"),
            PL("Gender__c", "Gender", ["Female", "Male", "Non-binary", "Prefer not to say"]),
            PL("Blood_Group__c", "Blood Group", ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]),
            CUR("Annual_CTC__c", "Annual CTC"),
            LT("Skills__c", "Skills", 4000, 3, help="Semicolon separated, e.g. Apex;LWC;Leadership"),
            LT("Career_Aspiration__c", "Career Aspiration", 4000, 3),
            T("Emergency_Contact_Name__c", "Emergency Contact Name", 120),
            PH("Emergency_Contact_Phone__c", "Emergency Contact Phone"),
            PL("Background_Check_Status__c", "Background Check", ["Not Started", "In Progress", "Cleared", "Flagged"], default="Not Started"),
            CB("Education_Verified__c", "Education Verified"),
            CB("Previous_Employment_Verified__c", "Previous Employment Verified"),
            CB("Bank_Details_Verified__c", "Bank Details Verified"),
            CB("Handbook_Acknowledged__c", "Handbook Acknowledged"),
            N("Casual_Leave_Balance__c", "Casual Leave Balance", 5, 1, default=12),
            N("Sick_Leave_Balance__c", "Sick Leave Balance", 5, 1, default=10),
            N("Earned_Leave_Balance__c", "Earned Leave Balance", 5, 1, default=15),
            N("Profile_Completeness__c", "Profile Completeness %", 3, 0, help="Calculated automatically."),
            N("Performance_Rating__c", "Latest Performance Rating", 2, 1),
            PL("Attrition_Risk__c", "Attrition Risk", ["Low", "Medium", "High"], help="Transparent heuristic recalculated daily."),
            CB("Critical_Role__c", "Critical Role"),
            PL("Succession_Readiness__c", "Succession Readiness", ["Ready Now", "1-2 Years", "3+ Years", "Not Identified"]),
            CB("Rehire_Eligible__c", "Rehire Eligible", True),
            N("Recognition_Points__c", "Recognition Points", 8, 0, default=0),
            F("Tenure_Years__c", "Tenure (Years)", "Number",
              "IF(ISBLANK(Date_of_Joining__c), 0, (BLANKVALUE(Exit_Date__c, TODAY()) - Date_of_Joining__c) / 365)", 1),
        ]),
    OBJ("Employment_History__c", "Employment Event", "Employment History", ("AutoNumber", "Event Number", "EH-{000000}"),
        sharing="ControlledByParent", tab=False, list_cols=["Employee__c", "Event_Type__c", "Effective_Date__c"], fields=[
            MD("Employee__c", "Employee", "Employee__c", "Employment_History"),
            PL("Event_Type__c", "Event Type", ["Joined", "Status Change", "Promotion", "Transfer", "Designation Change",
                                               "Manager Change", "Location Change", "Compensation Change", "Exit"]),
            D("Effective_Date__c", "Effective Date"),
            T("Field_Changed__c", "Field Changed", 80),
            T("Previous_Value__c", "Previous Value"),
            T("New_Value__c", "New Value"),
            LT("Notes__c", "Notes", 5000),
            LK("Changed_By__c", "Changed By", "User", "PS_Employment_Changes"),
        ]),
    OBJ("Employee_Document__c", "Employee Document", "Employee Documents", sharing="ControlledByParent",
        icon="Custom18: Form", list_cols=["Employee__c", "Document_Type__c", "Verification_Status__c", "Expiry_Date__c"], fields=[
            MD("Employee__c", "Employee", "Employee__c", "Documents"),
            PL("Document_Type__c", "Document Type", ["Offer Letter", "Aadhaar Card", "PAN Card", "Passport", "Degree Certificate",
                                                     "Experience Letter", "Relieving Letter", "Bank Proof", "Address Proof",
                                                     "Photograph", "Visa / Work Permit", "Signed Policy", "Other"]),
            PL("Verification_Status__c", "Verification Status", ["Pending Upload", "Uploaded", "Verified", "Rejected", "Expired"], default="Pending Upload"),
            CB("Mandatory__c", "Mandatory"),
            T("Document_Reference__c", "Reference (last 4 only)", 10, help="Store only the last 4 characters of an ID number."),
            D("Expiry_Date__c", "Expiry Date"),
            LK("Verified_By__c", "Verified By", "User", "PS_Verified_Documents"),
            D("Verified_On__c", "Verified On"),
            T("Rejection_Reason__c", "Rejection Reason"),
            F("Days_To_Expiry__c", "Days to Expiry", "Number", "IF(ISBLANK(Expiry_Date__c), null, Expiry_Date__c - TODAY())", 0, blank_zero=False),
        ]),

    # ---------------- Onboarding / offboarding ----------------------------
    OBJ("Checklist_Template__c", "Checklist Template", "Checklist Templates", icon="Custom18: Form",
        desc="Configurable onboarding/offboarding workflow. The most specific active match is used.",
        list_cols=["Process_Type__c", "Department__c", "Location__c", "Employment_Type__c", "Active__c"], fields=[
            PL("Process_Type__c", "Process Type", ["Onboarding", "Offboarding"], default="Onboarding"),
            LK("Organization__c", "Organization", "Organization__c", "Checklist_Templates"),
            LK("Department__c", "Department", "Department__c", "Checklist_Templates"),
            LK("Location__c", "Location", "Location__c", "Checklist_Templates"),
            PL("Employment_Type__c", "Employment Type", EMP_TYPES),
            N("Duration_Days__c", "Target Duration (Days)", 3, 0, default=30),
            CB("Active__c", "Active", True),
            LT("Description__c", "Description", 5000),
        ]),
    OBJ("Checklist_Template_Item__c", "Checklist Template Item", "Checklist Template Items", ("Text", "Task Name", None),
        sharing="ControlledByParent", tab=False, list_cols=["Checklist_Template__c", "Assigned_Team__c", "Days_Offset__c"], fields=[
            MD("Checklist_Template__c", "Checklist Template", "Checklist_Template__c", "Items"),
            PL("Assigned_Team__c", "Assigned Team", TEAMS, default="HR"),
            PL("Category__c", "Category", TASK_CATEGORY),
            N("Days_Offset__c", "Due (Days From Start)", 3, 0, default=0, help="Negative values are due before the start date."),
            CB("Mandatory__c", "Mandatory", True),
            N("Sequence__c", "Sequence", 4, 0),
            LT("Description__c", "Description", 5000),
        ]),
    OBJ("Onboarding__c", "Onboarding", "Onboardings", ("AutoNumber", "Onboarding Number", "ONB-{00000}"),
        icon="Custom20: Airplane", list_cols=["Employee__c", "Status__c", "Start_Date__c", "Completion_Percent__c"], fields=[
            LK("Employee__c", "Employee", "Employee__c", "Onboardings", req=True),
            PL("Status__c", "Status", ["Not Started", "In Progress", "Completed", "On Hold", "Cancelled"], default="Not Started"),
            D("Start_Date__c", "Start Date"),
            D("Target_Completion_Date__c", "Target Completion Date"),
            D("Completed_On__c", "Completed On"),
            LK("Checklist_Template__c", "Checklist Template", "Checklist_Template__c", "Onboardings"),
            LK("Buddy__c", "Onboarding Buddy", "Employee__c", "Onboarding_Buddies"),
            LT("Welcome_Message__c", "Welcome Message", 5000),
            RS("Total_Tasks__c", "Total Tasks", "count", "Onboarding_Task__c", "Onboarding__c"),
            RS("Completed_Tasks__c", "Completed Tasks", "count", "Onboarding_Task__c", "Onboarding__c",
               filters=[("Status__c", "equals", "Completed")]),
            F("Completion_Percent__c", "Completion %", "Percent", "IF(Total_Tasks__c = 0, 0, Completed_Tasks__c / Total_Tasks__c)", 0),
            F("Days_Elapsed__c", "Days Elapsed", "Number", "IF(ISBLANK(Start_Date__c), 0, BLANKVALUE(Completed_On__c, TODAY()) - Start_Date__c)", 0),
        ]),
    OBJ("Onboarding_Task__c", "Onboarding Task", "Onboarding Tasks", ("Text", "Task Name", None),
        sharing="ControlledByParent", icon="Custom18: Form",
        list_cols=["Onboarding__c", "Assigned_Team__c", "Status__c", "Due_Date__c"],
        fields=[MD("Onboarding__c", "Onboarding", "Onboarding__c", "Tasks")] + task_fields("PS_Onboarding_Tasks") + [
            F("Employee_Name__c", "Employee", "Text", "Onboarding__r.Employee__r.Name"),
        ]),
    OBJ("Exit_Process__c", "Exit Process", "Exit Processes", ("AutoNumber", "Exit Number", "EXIT-{00000}"),
        sharing="ControlledByParent", icon="Custom13: Box", history=True,
        list_cols=["Employee__c", "Exit_Type__c", "Status__c", "Last_Working_Day__c"], fields=[
            MD("Employee__c", "Employee", "Employee__c", "Exit_Processes"),
            PL("Exit_Type__c", "Exit Type", ["Resignation", "Termination", "Retirement", "Contract End", "Mutual Separation", "Absconding"], default="Resignation"),
            PL("Exit_Reason__c", "Exit Reason", ["Better Opportunity", "Compensation", "Career Growth", "Relocation", "Personal",
                                                 "Higher Studies", "Health", "Work-Life Balance", "Management", "Performance", "Other"]),
            PL("Status__c", "Status", ["Submitted", "Manager Approved", "Clearance In Progress", "Ready for Settlement",
                                       "Settled", "Completed", "Withdrawn", "Rejected"], default="Submitted"),
            D("Resignation_Date__c", "Resignation Date"),
            N("Notice_Period_Days__c", "Notice Period (Days)", 3, 0),
            D("Last_Working_Day__c", "Last Working Day"),
            DT("Exit_Interview_Date__c", "Exit Interview"),
            LT("Exit_Interview_Notes__c", "Exit Interview Notes", 10000),
            PL("Knowledge_Transfer_Status__c", "Knowledge Transfer", ["Not Started", "In Progress", "Completed", "Not Required"], default="Not Started"),
            LK("KT_Recipient__c", "KT Recipient", "Employee__c", "KT_Received"),
            N("Pending_Assets__c", "Pending Assets", 3, 0),
            CUR("Pending_Expenses__c", "Pending Expenses"),
            CUR("Final_Settlement_Amount__c", "Final Settlement Amount"),
            D("Settlement_Date__c", "Settlement Date"),
            CB("Rehire_Eligible__c", "Rehire Eligible", True),
            CB("Experience_Letter_Issued__c", "Experience Letter Issued"),
            LT("Manager_Comments__c", "Manager Comments", 5000),
            RS("Total_Clearance_Tasks__c", "Total Clearance Tasks", "count", "Exit_Task__c", "Exit_Process__c"),
            RS("Completed_Clearance_Tasks__c", "Completed Clearance Tasks", "count", "Exit_Task__c", "Exit_Process__c",
               filters=[("Status__c", "equals", "Completed")]),
            F("Clearance_Percent__c", "Clearance %", "Percent",
              "IF(Total_Clearance_Tasks__c = 0, 0, Completed_Clearance_Tasks__c / Total_Clearance_Tasks__c)", 0),
        ]),
    OBJ("Exit_Task__c", "Clearance Task", "Clearance Tasks", ("Text", "Task Name", None), sharing="ControlledByParent", tab=False,
        list_cols=["Exit_Process__c", "Assigned_Team__c", "Status__c", "Due_Date__c"],
        fields=[MD("Exit_Process__c", "Exit Process", "Exit_Process__c", "Clearance_Tasks")] + task_fields("PS_Exit_Tasks")),

    # ---------------- Learning --------------------------------------------
    OBJ("Learning_Course__c", "Learning Course", "Learning Courses", ("Text", "Course Title", None),
        icon="Custom55: Books", list_cols=["Course_Code__c", "Category__c", "Delivery_Mode__c", "Mandatory__c", "Active__c"], fields=[
            T("Course_Code__c", "Course Code", 30, unique=True, ext=True),
            PL("Category__c", "Category", ["Compliance", "Technical", "Leadership", "Soft Skills", "Product", "Safety",
                                           "Onboarding", "Information Security"]),
            PL("Delivery_Mode__c", "Delivery Mode", ["Video", "Document", "Classroom", "Virtual Instructor-led", "Blended", "Quiz Only"], default="Video"),
            PL("Level__c", "Level", ["Beginner", "Intermediate", "Advanced"], default="Beginner"),
            URL("Content_URL__c", "Content URL"),
            LT("Description__c", "Description", 10000),
            N("Duration_Hours__c", "Duration (Hours)", 5, 1),
            CB("Mandatory__c", "Mandatory", help="Auto-assigned to every employee in the target department (or everyone if blank)."),
            LK("Target_Department__c", "Target Department", "Department__c", "Courses"),
            LK("Prerequisite_Course__c", "Prerequisite Course", "Learning_Course__c", "Dependent_Courses"),
            LK("Instructor__c", "Instructor", "Employee__c", "Courses_Taught"),
            N("Passing_Score__c", "Passing Score %", 3, 0, default=70),
            N("Due_In_Days__c", "Due In (Days)", 3, 0, default=30),
            N("Certification_Validity_Months__c", "Certification Validity (Months)", 3, 0,
              help="If set, passing the course issues a certification that expires after this many months."),
            T("Skills_Covered__c", "Skills Covered", 255, help="Semicolon separated."),
            CB("Active__c", "Active", True),
            RS("Total_Questions__c", "Quiz Questions", "count", "Quiz_Question__c", "Course__c"),
        ]),
    OBJ("Quiz_Question__c", "Quiz Question", "Quiz Questions", ("AutoNumber", "Question Number", "Q-{00000}"),
        sharing="ControlledByParent", tab=False, list_cols=["Course__c", "Question__c", "Correct_Option__c"], fields=[
            MD("Course__c", "Course", "Learning_Course__c", "Questions"),
            T("Question__c", "Question", 255),
            T("Option_A__c", "Option A"), T("Option_B__c", "Option B"),
            T("Option_C__c", "Option C"), T("Option_D__c", "Option D"),
            PL("Correct_Option__c", "Correct Option", ["A", "B", "C", "D"]),
            N("Points__c", "Points", 3, 0, default=1),
            N("Sequence__c", "Sequence", 4, 0),
            LT("Explanation__c", "Explanation", 2000),
        ]),
    OBJ("Learning_Enrollment__c", "Learning Enrollment", "Learning Enrollments", ("AutoNumber", "Enrollment Number", "ENR-{000000}"),
        sharing="ControlledByParent", icon="Custom55: Books",
        list_cols=["Employee__c", "Course__c", "Status__c", "Due_Date__c", "Score__c"], fields=[
            MD("Employee__c", "Employee", "Employee__c", "Enrollments"),
            LK("Course__c", "Course", "Learning_Course__c", "Enrollments", req=True),
            PL("Status__c", "Status", ["Assigned", "In Progress", "Completed", "Failed", "Overdue", "Waived"], default="Assigned"),
            N("Progress_Percent__c", "Progress %", 3, 0, default=0),
            D("Assigned_On__c", "Assigned On"),
            D("Due_Date__c", "Due Date"),
            D("Completion_Date__c", "Completion Date"),
            N("Score__c", "Score %", 5, 1),
            N("Attempts__c", "Attempts", 3, 0, default=0),
            PL("Assignment_Source__c", "Assignment Source", ["Manual", "Mandatory Rule", "Department Rule", "Transfer Rule",
                                                             "Skill Gap", "AI Recommendation", "Self Enrolled"], default="Manual"),
            F("Is_Overdue__c", "Overdue", "Checkbox",
              "AND(NOT(ISPICKVAL(Status__c,'Completed')), NOT(ISPICKVAL(Status__c,'Waived')), NOT(ISBLANK(Due_Date__c)), Due_Date__c < TODAY())"),
        ]),
    OBJ("Certification__c", "Certification", "Certifications", ("Text", "Certification Name", None),
        sharing="ControlledByParent", icon="Custom44: Award",
        list_cols=["Employee__c", "Issued_On__c", "Expires_On__c", "Status__c"], fields=[
            MD("Employee__c", "Employee", "Employee__c", "Certifications"),
            LK("Course__c", "Course", "Learning_Course__c", "Certifications"),
            T("Certificate_Number__c", "Certificate Number", 40),
            T("Issuing_Authority__c", "Issuing Authority", 120),
            D("Issued_On__c", "Issued On"),
            D("Expires_On__c", "Expires On"),
            URL("Credential_URL__c", "Credential URL"),
            F("Status__c", "Status", "Text",
              "IF(ISBLANK(Expires_On__c), 'Active', IF(Expires_On__c < TODAY(), 'Expired', IF(Expires_On__c - TODAY() <= 30, 'Expiring Soon', 'Active')))"),
        ]),

    # ---------------- Performance & career --------------------------------
    OBJ("Performance_Review__c", "Performance Review", "Performance Reviews", ("AutoNumber", "Review Number", "PR-{00000}"),
        sharing="ControlledByParent", icon="Custom48: Ribbon", history=True,
        list_cols=["Employee__c", "Review_Cycle__c", "Review_Year__c", "Status__c", "Final_Rating__c"], fields=[
            MD("Employee__c", "Employee", "Employee__c", "Performance_Reviews"),
            LK("Reviewer__c", "Reviewer", "Employee__c", "Reviews_Given"),
            PL("Review_Cycle__c", "Review Cycle", ["Q1", "Q2", "Q3", "Q4", "Mid-Year", "Annual", "Probation"], default="Annual"),
            T("Review_Year__c", "Review Year", 4),
            PL("Status__c", "Status", ["Not Started", "Self Assessment", "Manager Review", "Calibration", "Completed"], default="Not Started"),
            D("Due_Date__c", "Due Date"),
            N("Self_Rating__c", "Self Rating (1-5)", 2, 1),
            N("Manager_Rating__c", "Manager Rating (1-5)", 2, 1),
            N("Final_Rating__c", "Final Rating (1-5)", 2, 1),
            LT("Self_Assessment__c", "Self Assessment", 10000),
            LT("Manager_Feedback__c", "Manager Feedback", 10000),
            LT("Strengths__c", "Strengths", 5000),
            LT("Improvement_Areas__c", "Improvement Areas", 5000),
            CB("Promotion_Recommended__c", "Promotion Recommended"),
            CB("PIP_Required__c", "Performance Improvement Plan"),
            D("Completed_On__c", "Completed On"),
            F("Is_Overdue__c", "Overdue", "Checkbox",
              "AND(NOT(ISPICKVAL(Status__c,'Completed')), NOT(ISBLANK(Due_Date__c)), Due_Date__c < TODAY())"),
        ]),
    OBJ("Goal__c", "Goal", "Goals", icon="Custom11: Target",
        list_cols=["Employee__c", "Goal_Type__c", "Status__c", "Progress__c", "Due_Date__c"], fields=[
            LK("Employee__c", "Employee", "Employee__c", "Goals"),
            LK("Department__c", "Department", "Department__c", "Goals"),
            LK("Parent_Goal__c", "Aligned To (Parent Goal)", "Goal__c", "Child_Goals"),
            LK("Performance_Review__c", "Performance Review", "Performance_Review__c", "Goals"),
            PL("Goal_Type__c", "Goal Type", ["Company", "Department", "Team", "Individual"], default="Individual"),
            PL("Framework__c", "Framework", ["OKR", "KPI", "SMART"], default="OKR"),
            T("Key_Result__c", "Key Result / KPI"),
            N("Target_Value__c", "Target Value", 16, 2),
            N("Current_Value__c", "Current Value", 16, 2, default=0),
            T("Unit__c", "Unit", 20),
            N("Weightage__c", "Weightage %", 3, 0),
            PL("Status__c", "Status", ["Not Started", "On Track", "At Risk", "Behind", "Achieved", "Cancelled"], default="Not Started"),
            D("Start_Date__c", "Start Date"),
            D("Due_Date__c", "Due Date"),
            F("Progress__c", "Progress", "Percent",
              "IF(OR(ISBLANK(Target_Value__c), Target_Value__c = 0), 0, MIN(1, BLANKVALUE(Current_Value__c,0) / Target_Value__c))", 0),
        ]),
    OBJ("Compensation_Revision__c", "Compensation Revision", "Compensation Revisions", ("AutoNumber", "Revision Number", "CR-{00000}"),
        sharing="ControlledByParent", icon="Custom41: Moneybag",
        list_cols=["Employee__c", "Reason__c", "Status__c", "Effective_Date__c", "Change_Percent__c"], fields=[
            MD("Employee__c", "Employee", "Employee__c", "Compensation_Revisions"),
            PL("Reason__c", "Reason", ["Annual Increment", "Promotion", "Market Correction", "Retention", "Bonus", "Other"], default="Annual Increment"),
            PL("Status__c", "Status", ["Proposed", "Approved", "Rejected", "Applied"], default="Proposed"),
            D("Effective_Date__c", "Effective Date"),
            CUR("Previous_CTC__c", "Previous CTC"),
            CUR("New_CTC__c", "New CTC"),
            CUR("Bonus_Amount__c", "One-time Bonus"),
            LK("Approved_By__c", "Approved By", "User", "PS_Compensation_Approvals"),
            LT("Justification__c", "Justification", 5000),
            F("Change_Percent__c", "Change %", "Percent",
              "IF(OR(ISBLANK(Previous_CTC__c), Previous_CTC__c = 0), 0, (New_CTC__c - Previous_CTC__c) / Previous_CTC__c)", 1),
        ]),
    OBJ("Mentorship__c", "Mentorship", "Mentorships", ("AutoNumber", "Mentorship Number", "MEN-{00000}"),
        icon="Custom1: Heart", list_cols=["Mentor__c", "Mentee__c", "Focus_Area__c", "Status__c"], fields=[
            LK("Mentor__c", "Mentor", "Employee__c", "Mentees"),
            LK("Mentee__c", "Mentee", "Employee__c", "Mentors"),
            T("Focus_Area__c", "Focus Area", 120),
            PL("Status__c", "Status", ["Proposed", "Active", "Completed", "Cancelled"], default="Active"),
            D("Start_Date__c", "Start Date"),
            D("End_Date__c", "End Date"),
            LT("Notes__c", "Notes", 5000),
        ]),

    # ---------------- Attendance & leave ----------------------------------
    OBJ("Holiday__c", "Holiday", "Holidays", icon="Custom29: Sun",
        list_cols=["Holiday_Date__c", "Location__c", "Optional__c"], fields=[
            D("Holiday_Date__c", "Date", req=True),
            LK("Organization__c", "Organization", "Organization__c", "Holidays"),
            LK("Location__c", "Location", "Location__c", "Holidays", "Holidays"),
            CB("Optional__c", "Optional Holiday"),
        ]),
    OBJ("Leave_Request__c", "Leave Request", "Leave Requests", ("AutoNumber", "Leave Number", "LV-{00000}"),
        sharing="ControlledByParent", icon="Custom29: Sun",
        list_cols=["Employee__c", "Leave_Type__c", "Start_Date__c", "End_Date__c", "Number_of_Days__c", "Status__c"], fields=[
            MD("Employee__c", "Employee", "Employee__c", "Leave_Requests"),
            PL("Leave_Type__c", "Leave Type", ["Casual Leave", "Sick Leave", "Earned Leave", "Work From Home", "Unpaid Leave",
                                               "Maternity Leave", "Paternity Leave", "Bereavement Leave", "Comp Off"], default="Casual Leave"),
            D("Start_Date__c", "Start Date", req=True),
            D("End_Date__c", "End Date", req=True),
            CB("Half_Day__c", "Half Day"),
            N("Number_of_Days__c", "Working Days", 5, 1, help="Calculated: excludes weekends and holidays."),
            PL("Status__c", "Status", ["Draft", "Submitted", "Approved", "Rejected", "Cancelled"], default="Submitted"),
            LT("Reason__c", "Reason", 2000),
            LK("Approver__c", "Approver", "User", "PS_Leave_Approvals"),
            T("Approver_Comments__c", "Approver Comments"),
            DT("Decision_Date__c", "Decision Date"),
        ]),
    OBJ("Attendance__c", "Attendance", "Attendance", ("AutoNumber", "Attendance Number", "ATT-{0000000}"),
        sharing="ControlledByParent", icon="Custom25: Alarm clock",
        list_cols=["Employee__c", "Attendance_Date__c", "Status__c", "Hours_Worked__c", "Late_Arrival__c"], fields=[
            MD("Employee__c", "Employee", "Employee__c", "Attendance"),
            D("Attendance_Date__c", "Date", req=True),
            DT("Check_In__c", "Check In"),
            DT("Check_Out__c", "Check Out"),
            PL("Status__c", "Status", ["Present", "Absent", "Half Day", "Work From Home", "On Leave", "Holiday", "Weekend"], default="Present"),
            PL("Work_Mode__c", "Work Mode", WORK_MODES, default="Office"),
            PL("Shift__c", "Shift", ["General", "Morning", "Evening", "Night"], default="General"),
            CB("Late_Arrival__c", "Late Arrival"),
            T("Unique_Key__c", "Unique Key", 40, unique=True, ext=True),
            T("Notes__c", "Notes"),
            F("Hours_Worked__c", "Hours Worked", "Number",
              "IF(OR(ISBLANK(Check_In__c), ISBLANK(Check_Out__c)), 0, (Check_Out__c - Check_In__c) * 24)", 2),
            F("Overtime_Hours__c", "Overtime Hours", "Number",
              "IF(OR(ISBLANK(Check_In__c), ISBLANK(Check_Out__c)), 0, MAX(0, (Check_Out__c - Check_In__c) * 24 - 9))", 2),
        ]),

    # ---------------- HR service desk & policy ----------------------------
    OBJ("HR_Policy__c", "HR Policy", "HR Policies", ("Text", "Policy Title", None), icon="Custom55: Books",
        desc="Company policies - also the knowledge base used by the HR assistant.",
        list_cols=["Category__c", "Version__c", "Effective_Date__c", "Requires_Acknowledgement__c", "Active__c"], fields=[
            PL("Category__c", "Category", ["Leave", "Attendance", "Code of Conduct", "Benefits", "Travel & Expense", "IT & Security",
                                           "Data Privacy", "Health & Safety", "Remote Work", "Performance", "Compensation",
                                           "Exit", "Anti-Harassment", "Learning"]),
            T("Summary__c", "Summary"),
            LT("Policy_Body__c", "Policy Text", 32768, 10),
            T("Keywords__c", "Keywords", 255, help="Comma separated. Improves assistant and ticket matching."),
            T("Version__c", "Version", 10),
            D("Effective_Date__c", "Effective Date"),
            CB("Requires_Acknowledgement__c", "Requires Acknowledgement"),
            CB("Active__c", "Active", True),
            LK("Owner_Department__c", "Owner Department", "Department__c", "Policies"),
            RS("Acknowledgement_Count__c", "Acknowledgements", "count", "Policy_Acknowledgement__c", "HR_Policy__c"),
        ]),
    OBJ("Policy_Acknowledgement__c", "Policy Acknowledgement", "Policy Acknowledgements", ("AutoNumber", "Acknowledgement Number", "ACK-{000000}"),
        sharing="ControlledByParent", tab=False, list_cols=["HR_Policy__c", "Employee__c", "Acknowledged_On__c"], fields=[
            MD("HR_Policy__c", "Policy", "HR_Policy__c", "Acknowledgements"),
            LK("Employee__c", "Employee", "Employee__c", "Policy_Acknowledgements", req=True),
            DT("Acknowledged_On__c", "Acknowledged On"),
            T("Version__c", "Version", 10),
            T("Unique_Key__c", "Unique Key", 40, unique=True, ext=True),
        ]),
    OBJ("HR_Ticket__c", "HR Ticket", "HR Tickets", ("AutoNumber", "Ticket Number", "HRT-{00000}"),
        sharing="Private", history=True, icon="Custom31: Bell",
        list_cols=["Subject__c", "Employee__c", "Category__c", "Priority__c", "Status__c", "SLA_Due__c"], fields=[
            T("Subject__c", "Subject", 255),
            LT("Description__c", "Description", 32000, 6),
            LK("Employee__c", "Employee", "Employee__c", "HR_Tickets"),
            PL("Category__c", "Category", ["Payroll", "Leave & Attendance", "Benefits & Insurance", "Policy Question", "IT Access",
                                           "Documents & Letters", "Onboarding", "Exit & Settlement", "Grievance", "Learning", "Other"], default="Other"),
            PL("Priority__c", "Priority", PRIORITY, default="Medium"),
            PL("Status__c", "Status", ["New", "In Progress", "Waiting on Employee", "Escalated", "Resolved", "Closed"], default="New"),
            PL("Channel__c", "Channel", ["Portal", "Email", "Chat", "Phone", "AI Assistant"], default="Portal"),
            LK("Assigned_To__c", "Assigned To", "User", "PS_Assigned_HR_Tickets"),
            DT("SLA_Due__c", "SLA Due"),
            DT("First_Response_At__c", "First Response At"),
            DT("Resolved_On__c", "Resolved On"),
            CB("Escalated__c", "Escalated"),
            N("Escalation_Level__c", "Escalation Level", 2, 0, default=0),
            CB("Confidential__c", "Confidential"),
            LT("Resolution__c", "Resolution", 10000),
            PL("Satisfaction_Rating__c", "Satisfaction (1-5)", ["1", "2", "3", "4", "5"]),
            T("Feedback__c", "Feedback"),
            T("AI_Suggested_Category__c", "AI Suggested Category", 80),
            N("AI_Confidence__c", "AI Confidence %", 3, 0),
            LK("Related_Policy__c", "Suggested Policy", "HR_Policy__c", "Tickets"),
            F("SLA_Breached__c", "SLA Breached", "Checkbox",
              "AND(NOT(ISBLANK(SLA_Due__c)), OR(AND(ISBLANK(Resolved_On__c), SLA_Due__c < NOW()), AND(NOT(ISBLANK(Resolved_On__c)), Resolved_On__c > SLA_Due__c)))"),
        ]),

    # ---------------- Assets & expenses -----------------------------------
    OBJ("Company_Asset__c", "Company Asset", "Company Assets", ("Text", "Asset Name", None), history=True,
        icon="Custom62: Laptop", list_cols=["Asset_Tag__c", "Asset_Type__c", "Status__c", "Assigned_To__c"], fields=[
            T("Asset_Tag__c", "Asset Tag", 40, unique=True, ext=True),
            PL("Asset_Type__c", "Asset Type", ["Laptop", "Desktop", "Monitor", "Mobile Phone", "Access Card", "Headset",
                                               "Software License", "Vehicle", "Other"], default="Laptop"),
            T("Serial_Number__c", "Serial Number", 80),
            PL("Status__c", "Status", ["In Stock", "Assigned", "In Repair", "Retired", "Lost"], default="In Stock"),
            PL("Condition__c", "Condition", ["New", "Good", "Fair", "Damaged"], default="New"),
            LK("Assigned_To__c", "Assigned To", "Employee__c", "Assets"),
            D("Assigned_On__c", "Assigned On"),
            D("Return_Due_Date__c", "Return Due Date"),
            D("Returned_On__c", "Returned On"),
            LK("Location__c", "Location", "Location__c", "Assets"),
            T("Vendor__c", "Vendor", 120),
            D("Purchase_Date__c", "Purchase Date"),
            CUR("Purchase_Cost__c", "Purchase Cost"),
            D("Warranty_Expiry__c", "Warranty Expiry"),
            LT("Notes__c", "Notes", 5000),
        ]),
    OBJ("Expense_Claim__c", "Expense Claim", "Expense Claims", ("AutoNumber", "Claim Number", "EXP-{00000}"),
        sharing="ControlledByParent", icon="Custom41: Moneybag",
        list_cols=["Employee__c", "Category__c", "Amount__c", "Expense_Date__c", "Status__c"], fields=[
            MD("Employee__c", "Employee", "Employee__c", "Expense_Claims"),
            PL("Category__c", "Category", ["Travel", "Food", "Accommodation", "Internet & Phone", "Training", "Medical",
                                           "Relocation", "Client Entertainment", "Other"], default="Travel"),
            CUR("Amount__c", "Amount"),
            D("Expense_Date__c", "Expense Date"),
            PL("Status__c", "Status", ["Draft", "Submitted", "Approved", "Rejected", "Paid"], default="Submitted"),
            LK("Approver__c", "Approver", "User", "PS_Expense_Approvals"),
            LT("Description__c", "Description", 2000),
            CB("Receipt_Attached__c", "Receipt Attached"),
            T("Approver_Comments__c", "Approver Comments"),
            DT("Decision_Date__c", "Decision Date"),
        ]),

    # ---------------- Recruitment -----------------------------------------
    OBJ("Job_Requisition__c", "Job Requisition", "Job Requisitions", ("Text", "Job Title", None),
        icon="Custom14: Hands", list_cols=["Department__c", "Location__c", "Status__c", "Openings__c", "Filled__c"], fields=[
            LK("Department__c", "Department", "Department__c", "Requisitions"),
            LK("Location__c", "Location", "Location__c", "Requisitions"),
            LK("Designation__c", "Designation", "Designation__c", "Requisitions"),
            LK("Hiring_Manager__c", "Hiring Manager", "Employee__c", "Requisitions_Managed"),
            PL("Status__c", "Status", ["Draft", "Pending Approval", "Open", "On Hold", "Filled", "Cancelled"], default="Draft"),
            PL("Priority__c", "Priority", PRIORITY, default="Medium"),
            PL("Employment_Type__c", "Employment Type", EMP_TYPES, default="Full-time"),
            N("Openings__c", "Openings", 4, 0, default=1),
            N("Filled__c", "Filled", 4, 0, default=0),
            CB("Internal_Posting__c", "Post on Internal Job Marketplace"),
            T("Required_Skills__c", "Required Skills", 255, help="Semicolon separated."),
            N("Min_Experience_Years__c", "Min Experience (Years)", 3, 1),
            CUR("Budget_Max_CTC__c", "Budget Max CTC"),
            D("Target_Hire_Date__c", "Target Hire Date"),
            D("Posted_On__c", "Posted On"),
            LK("Approved_By__c", "Approved By", "User", "PS_Approved_Requisitions"),
            LT("Job_Description__c", "Job Description", 32000, 8),
            F("Days_Open__c", "Days Open", "Number", "IF(ISBLANK(Posted_On__c), 0, TODAY() - Posted_On__c)", 0),
        ]),
    OBJ("Candidate__c", "Candidate", "Candidates", ("Text", "Candidate Name", None), sharing="Private",
        icon="Custom14: Hands", list_cols=["Job_Requisition__c", "Stage__c", "Source__c", "Match_Score__c"], fields=[
            EM("Email__c", "Email"),
            PH("Phone__c", "Phone"),
            LK("Job_Requisition__c", "Job Requisition", "Job_Requisition__c", "Candidates"),
            PL("Stage__c", "Stage", ["Applied", "Screening", "Interview", "Offer", "Offer Accepted", "Hired", "Rejected", "Withdrawn"], default="Applied"),
            PL("Source__c", "Source", ["Referral", "LinkedIn", "Job Portal", "Company Website", "Agency", "Campus", "Internal"], default="Job Portal"),
            T("Current_Company__c", "Current Company", 120),
            N("Experience_Years__c", "Experience (Years)", 4, 1),
            CUR("Current_CTC__c", "Current CTC"),
            CUR("Expected_CTC__c", "Expected CTC"),
            CUR("Offered_CTC__c", "Offered CTC"),
            N("Notice_Period_Days__c", "Notice Period (Days)", 3, 0),
            T("Skills__c", "Skills", 255, help="Semicolon separated."),
            N("Match_Score__c", "Skill Match %", 3, 0),
            N("Overall_Rating__c", "Interview Rating", 2, 1),
            LT("Resume_Text__c", "Resume Text", 32000, 8),
            LT("Resume_Summary__c", "Resume Summary", 5000),
            PL("Offer_Status__c", "Offer Status", ["Not Released", "Released", "Accepted", "Declined", "Revoked"], default="Not Released"),
            D("Offer_Date__c", "Offer Date"),
            D("Expected_Joining_Date__c", "Expected Joining Date"),
            LK("Internal_Employee__c", "Internal Applicant", "Employee__c", "Internal_Applications"),
            LK("Referred_By__c", "Referred By", "Employee__c", "Referrals"),
            LK("Converted_Employee__c", "Converted Employee", "Employee__c", "Source_Candidates"),
            T("Rejection_Reason__c", "Rejection Reason"),
        ]),
    OBJ("Interview__c", "Interview", "Interviews", ("AutoNumber", "Interview Number", "INT-{00000}"),
        sharing="ControlledByParent", tab=False,
        list_cols=["Candidate__c", "Round__c", "Scheduled_At__c", "Status__c", "Recommendation__c"], fields=[
            MD("Candidate__c", "Candidate", "Candidate__c", "Interviews"),
            PL("Round__c", "Round", ["Screening", "Technical 1", "Technical 2", "Managerial", "HR", "Final"], default="Screening"),
            LK("Interviewer__c", "Interviewer", "User", "PS_Interviews"),
            DT("Scheduled_At__c", "Scheduled At"),
            N("Duration_Minutes__c", "Duration (Minutes)", 3, 0, default=45),
            PL("Mode__c", "Mode", ["Video", "In Person", "Phone"], default="Video"),
            URL("Meeting_Link__c", "Meeting Link"),
            PL("Status__c", "Status", ["Scheduled", "Completed", "Cancelled", "No Show"], default="Scheduled"),
            N("Rating__c", "Rating (1-5)", 2, 1),
            PL("Recommendation__c", "Recommendation", ["Strong Hire", "Hire", "Hold", "No Hire"]),
            LT("Feedback__c", "Feedback", 10000),
        ]),

    # ---------------- Engagement ------------------------------------------
    OBJ("Pulse_Survey__c", "Pulse Survey", "Pulse Surveys", ("Text", "Survey Title", None), icon="Custom1: Heart",
        list_cols=["Survey_Type__c", "Active__c", "Response_Count__c", "Average_Score__c"], fields=[
            T("Question__c", "Question", 255),
            PL("Survey_Type__c", "Survey Type", ["eNPS", "Pulse", "Engagement", "Onboarding Feedback", "Training Feedback", "Exit"], default="eNPS"),
            CB("Anonymous__c", "Anonymous", True),
            CB("Active__c", "Active", True),
            D("Start_Date__c", "Start Date"),
            D("End_Date__c", "End Date"),
            RS("Response_Count__c", "Responses", "count", "Survey_Response__c", "Pulse_Survey__c"),
            RS("Total_Score__c", "Total Score", "sum", "Survey_Response__c", "Pulse_Survey__c", field="Score__c"),
            F("Average_Score__c", "Average Score", "Number", "IF(Response_Count__c = 0, 0, Total_Score__c / Response_Count__c)", 1),
        ]),
    OBJ("Survey_Response__c", "Survey Response", "Survey Responses", ("AutoNumber", "Response Number", "SR-{000000}"),
        sharing="ControlledByParent", tab=False, list_cols=["Pulse_Survey__c", "Score__c", "Sentiment__c"], fields=[
            MD("Pulse_Survey__c", "Survey", "Pulse_Survey__c", "Responses"),
            N("Score__c", "Score (0-10)", 2, 0),
            LT("Comment__c", "Comment", 2000),
            LK("Employee__c", "Employee", "Employee__c", "Survey_Responses"),
            LK("Department__c", "Department", "Department__c", "Survey_Responses"),
            PL("Sentiment__c", "Sentiment", ["Positive", "Neutral", "Negative"]),
            T("Respondent_Key__c", "Respondent Key", 80, unique=True, ext=True, help="One-way hash: prevents duplicate answers without revealing who answered."),
        ]),
    OBJ("Recognition__c", "Recognition", "Recognitions", ("AutoNumber", "Recognition Number", "KUDOS-{00000}"),
        icon="Custom44: Award", list_cols=["Giver__c", "Recipient__c", "Badge__c", "Points__c"], fields=[
            LK("Giver__c", "From", "Employee__c", "Recognitions_Given"),
            LK("Recipient__c", "To", "Employee__c", "Recognitions_Received"),
            PL("Badge__c", "Badge", ["Team Player", "Innovator", "Customer Hero", "Leadership", "Above and Beyond", "Mentor", "Quality Champion"], default="Team Player"),
            LT("Message__c", "Message", 1000, 3),
            N("Points__c", "Points", 4, 0, default=10),
            PL("Visibility__c", "Visibility", ["Public", "Team", "Private"], default="Public"),
        ]),
    OBJ("Announcement__c", "Announcement", "Announcements", ("Text", "Title", None), icon="Custom53: Bell",
        list_cols=["Category__c", "Publish_Date__c", "Expiry_Date__c", "Pinned__c"], fields=[
            LT("Body__c", "Body", 10000, 5),
            PL("Category__c", "Category", ["General", "Policy", "Event", "Celebration", "IT", "Urgent"], default="General"),
            D("Publish_Date__c", "Publish Date"),
            D("Expiry_Date__c", "Expiry Date"),
            LK("Department__c", "Audience Department", "Department__c", "Announcements"),
            CB("Pinned__c", "Pinned"),
            DT("Event_Date__c", "Event Date"),
            T("Event_Location__c", "Event Location", 120),
        ]),
]

# Picklist in the SLA custom metadata type
SLA_MDT = dict(api="SLA_Policy__mdt", label="SLA Policy", plural="SLA Policies", fields=[
    N("Resolution_Hours__c", "Resolution Hours", 5, 0),
    N("First_Response_Hours__c", "First Response Hours", 5, 0),
])
SLA_RECORDS = [("Critical", 4, 1), ("High", 8, 2), ("Medium", 24, 4), ("Low", 72, 8)]


# ----------------------------------------------------------------------------
# XML writers
# ----------------------------------------------------------------------------
def w(path, body):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(HEAD + body)


def tag(name, value):
    if value is None:
        return ""
    if isinstance(value, bool):
        value = "true" if value else "false"
    return f"<{name}>{escape(str(value))}</{name}>"


def field_xml(f, obj_api=None):
    t = f["type"]
    parts = [tag("fullName", f["api"])]
    if f.get("help"):
        parts.append(tag("inlineHelpText", f["help"]))
    parts.append(tag("label", f["label"]))
    if t == "Text":
        parts += [tag("length", f["length"]), tag("required", f["req"]), tag("type", "Text"),
                  tag("unique", f["unique"]), tag("externalId", f["ext"])]
        if f["unique"]:
            parts.append(tag("caseSensitive", False))
    elif t == "LongTextArea":
        parts += [tag("length", f["length"]), tag("type", "LongTextArea"), tag("visibleLines", f["lines"])]
    elif t in ("Number", "Currency", "Percent"):
        parts += [tag("precision", f["precision"]), tag("scale", f["scale"]), tag("required", False), tag("type", t),
                  tag("unique", False), tag("externalId", False)] if t == "Number" else \
                 [tag("precision", f["precision"]), tag("scale", f["scale"]), tag("required", False), tag("type", t)]
        if f.get("default") is not None:
            parts.append(tag("defaultValue", f["default"]))
    elif t in ("Date", "DateTime", "Email", "Phone", "Url"):
        parts += [tag("required", f.get("req", False)), tag("type", t)]
        if t == "Email":
            parts += [tag("unique", False), tag("externalId", False)]
    elif t == "Checkbox":
        parts += [tag("defaultValue", f["default"]), tag("type", "Checkbox")]
    elif t == "Picklist":
        vals = "".join(
            f"<value><fullName>{escape(v)}</fullName><default>{'true' if v == f.get('default') else 'false'}</default>"
            f"<label>{escape(v)}</label></value>" for v in f["values"])
        parts += [tag("required", f.get("req", False)), tag("type", "Picklist"),
                  f"<valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>{vals}</valueSetDefinition></valueSet>"]
    elif t == "Lookup":
        if f["req"]:
            parts.append(tag("deleteConstraint", "Restrict"))
        elif f["ref"] != "User":
            parts.append(tag("deleteConstraint", "SetNull"))
        parts += [tag("referenceTo", f["ref"]), tag("relationshipLabel", f["rel_label"]),
                  tag("relationshipName", f["rel"]), tag("required", f["req"]), tag("type", "Lookup")]
    elif t == "MasterDetail":
        parts += [tag("referenceTo", f["ref"]), tag("relationshipLabel", f["rel_label"]),
                  tag("relationshipName", f["rel"]), tag("relationshipOrder", 0),
                  tag("reparentableMasterDetail", False), tag("type", "MasterDetail"),
                  tag("writeRequiresMasterRead", False)]
    elif t == "Formula":
        parts += [tag("formula", f["formula"]),
                  tag("formulaTreatBlanksAs", "BlankAsZero" if f["blank_zero"] else "BlankAsBlank")]
        if f["ftype"] in ("Number", "Percent", "Currency"):
            parts += [tag("precision", 18), tag("scale", f["scale"])]
        parts += [tag("type", f["ftype"])]
        if f["ftype"] == "Checkbox":
            pass
    elif t == "Summary":
        if f["field"]:
            parts.append(tag("summarizedField", f"{f['child']}.{f['field']}"))
        for (fld, op, val) in f["filters"]:
            parts.append(f"<summaryFilterItems><field>{f['child']}.{fld}</field><operation>{op}</operation>"
                         f"<value>{escape(val)}</value></summaryFilterItems>")
        parts += [tag("summaryForeignKey", f"{f['child']}.{f['fk']}"),
                  tag("summaryOperation", f["op"]), tag("type", "Summary")]
    if f.get("track"):
        parts.append(tag("trackHistory", True))
    return f'<CustomField {NS}>\n    ' + "\n    ".join(p for p in parts if p) + "\n</CustomField>\n"


TRACKED = {"Status__c", "Department__c", "Designation__c", "Manager__c", "Location__c", "Annual_CTC__c",
           "Priority__c", "Assigned_To__c", "Category__c", "Last_Working_Day__c", "Final_Rating__c"}


def object_xml(o):
    kind, label, fmt = o["name"]
    label = label or o["label"] + " Name"
    name_field = f"<nameField><label>{escape(label)}</label>"
    if kind == "AutoNumber":
        name_field += f"<displayFormat>{fmt}</displayFormat><type>AutoNumber</type>"
    else:
        name_field += "<type>Text</type>"
    name_field += "</nameField>"
    sharing = o["sharing"]
    ext = sharing if sharing != "ReadWrite" else "Private"
    if sharing == "ControlledByParent":
        ext = "ControlledByParent"
    return (f'<CustomObject {NS}>\n'
            f'    <deploymentStatus>Deployed</deploymentStatus>\n'
            f'    <description>{escape(o["desc"] or o["label"])}</description>\n'
            f'    <enableActivities>true</enableActivities>\n'
            f'    <enableBulkApi>true</enableBulkApi>\n'
            f'    <enableFeeds>false</enableFeeds>\n'
            f'    <enableHistory>{"true" if o["history"] else "false"}</enableHistory>\n'
            f'    <enableReports>true</enableReports>\n'
            f'    <enableSearch>true</enableSearch>\n'
            f'    <enableSharing>true</enableSharing>\n'
            f'    <enableStreamingApi>true</enableStreamingApi>\n'
            f'    <externalSharingModel>{ext}</externalSharingModel>\n'
            f'    <label>{escape(o["label"])}</label>\n'
            f'    {name_field}\n'
            f'    <pluralLabel>{escape(o["plural"])}</pluralLabel>\n'
            f'    <searchLayouts/>\n'
            f'    <sharingModel>{sharing}</sharingModel>\n'
            f'    <visibility>Public</visibility>\n'
            f'</CustomObject>\n')


def listview_xml(o):
    cols = "".join(f"<columns>{c}</columns>" for c in ["NAME"] + o["list_cols"])
    return (f'<ListView {NS}>\n    <fullName>All</fullName>\n    {cols}\n'
            f'    <filterScope>Everything</filterScope>\n    <label>All</label>\n</ListView>\n')


def layout_xml(o, children):
    editable = [f for f in o["fields"] if f["type"] not in ("Formula", "Summary")]
    readonly = [f for f in o["fields"] if f["type"] in ("Formula", "Summary")]

    def item(api, behavior):
        return f"<layoutItems><behavior>{behavior}</behavior><field>{api}</field></layoutItems>"

    def required(f):
        return f.get("req") or f["type"] == "MasterDetail"

    items = [item("Name", "Required" if o["name"][0] == "Text" else "Readonly")]
    items += [item(f["api"], "Required" if required(f) else "Edit") for f in editable]
    items += [item(f["api"], "Readonly") for f in readonly]
    half = (len(items) + 1) // 2
    col1, col2 = items[:half], items[half:]
    sys_items = item("OwnerId", "Edit") if o["sharing"] != "ControlledByParent" else ""
    sys_items += item("CreatedById", "Readonly") + item("LastModifiedById", "Readonly")
    related = "".join(
        f"<relatedLists><fields>NAME</fields><relatedList>{c}.{fk}</relatedList></relatedLists>" for c, fk in children)
    return (f'<Layout {NS}>\n'
            f'    <layoutSections><customLabel>false</customLabel><detailHeading>true</detailHeading><editHeading>true</editHeading>'
            f'<label>Information</label><layoutColumns>{"".join(col1)}</layoutColumns><layoutColumns>{"".join(col2)}</layoutColumns>'
            f'<style>TwoColumnsTopToBottom</style></layoutSections>\n'
            f'    <layoutSections><customLabel>false</customLabel><detailHeading>true</detailHeading><editHeading>false</editHeading>'
            f'<label>System Information</label><layoutColumns>{sys_items}</layoutColumns><layoutColumns/>'
            f'<style>TwoColumnsTopToBottom</style></layoutSections>\n'
            f'    {related}\n'
            f'    <showEmailCheckbox>false</showEmailCheckbox><showHighlightsPanel>false</showHighlightsPanel>'
            f'<showInteractionLogPanel>false</showInteractionLogPanel><showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox>'
            f'<showSubmitAndAttachButton>false</showSubmitAndAttachButton>\n'
            f'</Layout>\n')


def tab_xml(o):
    return (f'<CustomTab {NS}>\n    <customObject>true</customObject>\n'
            f'    <motif>{o["icon"]}</motif>\n</CustomTab>\n')


# ----------------------------------------------------------------------------
# Permission sets
# ----------------------------------------------------------------------------
# access codes: R read, C create+read+edit, D create/read/edit/delete, A all (view/modify all)
PERMSETS = {
    "PeopleSphere_Admin": ("PeopleSphere Administrator", "Full control of PeopleSphere data and configuration.",
                           {"*": "A"}),
    "PeopleSphere_HR": ("PeopleSphere HR Team", "HR operations: employees, lifecycle, learning, service desk, analytics.",
                        {"*": "A", "Organization__c": "R", "Business_Unit__c": "R", "SLA_Policy__mdt": "R"}),
    "PeopleSphere_Manager": ("PeopleSphere Manager", "Team management: approvals, reviews, goals, team dashboards.",
                             {"*": "R", "Performance_Review__c": "C", "Goal__c": "D", "Recognition__c": "C",
                              "Leave_Request__c": "C", "Expense_Claim__c": "C", "HR_Ticket__c": "C",
                              "Onboarding_Task__c": "C", "Exit_Task__c": "C", "Interview__c": "C",
                              "Job_Requisition__c": "C", "Mentorship__c": "C", "Attendance__c": "C",
                              "Survey_Response__c": "C", "Policy_Acknowledgement__c": "C", "Learning_Enrollment__c": "C",
                              "Candidate__c": "R", "Compensation_Revision__c": "C"}),
    "PeopleSphere_Employee": ("PeopleSphere Employee", "Employee self-service portal access.",
                              {"Organization__c": "R", "Business_Unit__c": "R", "Department__c": "R", "Location__c": "R",
                               "Designation__c": "R", "Employee__c": "R", "Employee_Document__c": "C",
                               "Onboarding__c": "R", "Onboarding_Task__c": "C", "Learning_Course__c": "R",
                               "Learning_Enrollment__c": "C", "Certification__c": "R", "Performance_Review__c": "C",
                               "Goal__c": "C", "Holiday__c": "R", "Leave_Request__c": "C", "Attendance__c": "C",
                               "HR_Policy__c": "R", "Policy_Acknowledgement__c": "C", "HR_Ticket__c": "C",
                               "Expense_Claim__c": "C", "Recognition__c": "C", "Announcement__c": "R",
                               "Pulse_Survey__c": "R", "Survey_Response__c": "C", "Job_Requisition__c": "R",
                               "Mentorship__c": "R", "Company_Asset__c": "R", "Exit_Process__c": "C",
                               "Employment_History__c": "R"}),
}

# Fields hidden from employees and managers (field-level security)
SENSITIVE = {"Annual_CTC__c", "Attrition_Risk__c", "Previous_CTC__c", "New_CTC__c", "Bonus_Amount__c",
             "Final_Settlement_Amount__c", "Current_CTC__c", "Expected_CTC__c", "Offered_CTC__c", "Correct_Option__c",
             "Explanation__c"}
TABS_FOR_ALL = ["PS_Home", "PS_My_Workspace", "PS_HR_Assistant"]
TABS_MANAGER = ["PS_Manager_Workspace", "PS_Org_Chart", "PS_Employee_360"]
TABS_HR = ["PS_HR_Console", "PS_Service_Desk", "PS_Recruitment", "PS_Data_Explorer"]


def permset_xml(api, label, desc, rules, objects):
    parts = [f"<description>{escape(desc)}</description>", "<hasActivationRequired>false</hasActivationRequired>",
             f"<label>{escape(label)}</label>",
             "<applicationVisibilities><application>PeopleSphere</application><visible>true</visible></applicationVisibilities>"]
    classes = ["PS_DashboardController", "PS_Employee360Controller", "PS_PortalController", "PS_ManagerController",
               "PS_AssistantController", "PS_OrgChartController", "PS_LearningController", "PS_OnboardingController",
               "PS_HrOpsController", "PS_DataExplorerController"]
    for c in sorted(classes):
        parts.append(f"<classAccesses><apexClass>{c}</apexClass><enabled>true</enabled></classAccesses>")
    field_perms, obj_perms, tabs = [], [], []
    restricted = api in ("PeopleSphere_Employee", "PeopleSphere_Manager")
    for o in sorted(objects, key=lambda x: x["api"]):
        code = rules.get(o["api"], rules.get("*"))
        if not code:
            continue
        c = code in ("C", "D", "A")
        d = code in ("D", "A")
        a = code == "A"
        obj_perms.append(
            f"<objectPermissions><allowCreate>{str(c).lower()}</allowCreate><allowDelete>{str(d).lower()}</allowDelete>"
            f"<allowEdit>{str(c).lower()}</allowEdit><allowRead>true</allowRead><modifyAllRecords>{str(a).lower()}</modifyAllRecords>"
            f"<object>{o['api']}</object><viewAllRecords>{str(a).lower()}</viewAllRecords></objectPermissions>")
        for f in sorted(o["fields"], key=lambda x: x["api"]):
            if f["type"] == "MasterDetail" or f.get("req"):
                continue
            if restricted and f["api"] in SENSITIVE:
                continue
            calc = f["type"] in ("Formula", "Summary")
            edit = c and not calc
            field_perms.append(
                f"<fieldPermissions><editable>{str(edit).lower()}</editable><field>{o['api']}.{f['api']}</field>"
                f"<readable>true</readable></fieldPermissions>")
        if o["tab"]:
            tabs.append(o["api"])
    tab_list = TABS_FOR_ALL + (TABS_MANAGER if api != "PeopleSphere_Employee" else []) + (TABS_HR if api in ("PeopleSphere_Admin", "PeopleSphere_HR") else [])
    if api == "PeopleSphere_Employee":
        tabs = []
    for t in sorted(tab_list) + sorted(tabs):
        parts.append(f"<tabSettings><tab>{t}</tab><visibility>Visible</visibility></tabSettings>")
    body = "\n    ".join(parts[:4] + parts[4:4 + len(classes)] + field_perms + obj_perms + parts[4 + len(classes):])
    if api in ("PeopleSphere_Admin", "PeopleSphere_HR"):
        body += "\n    <customMetadataTypeAccesses><enabled>true</enabled><name>SLA_Policy__mdt</name></customMetadataTypeAccesses>"
    return f'<PermissionSet {NS}>\n    {body}\n</PermissionSet>\n'


# ----------------------------------------------------------------------------
def main():
    obj_root = os.path.join(ROOT, "objects")
    children = {}
    for o in SCHEMA:
        for f in o["fields"]:
            if f["type"] in ("MasterDetail", "Lookup") and f["ref"] != "User":
                children.setdefault(f["ref"], []).append((o["api"], f["api"]))

    for o in SCHEMA:
        base = os.path.join(obj_root, o["api"])
        if os.path.isdir(base):
            shutil.rmtree(base)
        w(os.path.join(base, f"{o['api']}.object-meta.xml"), object_xml(o))
        for f in o["fields"]:
            if o["history"] and f["api"] in TRACKED and f["type"] not in ("Formula", "Summary", "LongTextArea"):
                f["track"] = True
            w(os.path.join(base, "fields", f"{f['api']}.field-meta.xml"), field_xml(f))
        w(os.path.join(base, "listViews", "All.listView-meta.xml"), listview_xml(o))
        w(os.path.join(ROOT, "layouts", f"{o['api']}-{o['label']} Layout.layout-meta.xml"),
          layout_xml(o, children.get(o["api"], [])[:8]))
        if o["tab"]:
            w(os.path.join(ROOT, "tabs", f"{o['api']}.tab-meta.xml"), tab_xml(o))

    # custom metadata type
    base = os.path.join(obj_root, SLA_MDT["api"])
    w(os.path.join(base, f"{SLA_MDT['api']}.object-meta.xml"),
      f'<CustomObject {NS}>\n    <label>{SLA_MDT["label"]}</label>\n    <pluralLabel>{SLA_MDT["plural"]}</pluralLabel>\n'
      f'    <visibility>Public</visibility>\n</CustomObject>\n')
    for f in SLA_MDT["fields"]:
        xml = field_xml(f).replace("<required>false</required>", "").replace(
            "<type>Number</type>", "<fieldManageability>SubscriberControlled</fieldManageability><type>Number</type>")
        xml = xml.replace("<unique>false</unique>", "").replace("<externalId>false</externalId>", "")
        w(os.path.join(base, "fields", f"{f['api']}.field-meta.xml"), xml)
    for name, res, first in SLA_RECORDS:
        w(os.path.join(ROOT, "customMetadata", f"SLA_Policy.{name}.md-meta.xml"),
          f'<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
          f'xmlns:xsd="http://www.w3.org/2001/XMLSchema">\n    <label>{name}</label>\n    <protected>false</protected>\n'
          f'    <values><field>Resolution_Hours__c</field><value xsi:type="xsd:double">{res}</value></values>\n'
          f'    <values><field>First_Response_Hours__c</field><value xsi:type="xsd:double">{first}</value></values>\n'
          f'</CustomMetadata>\n')

    for api, (label, desc, rules) in PERMSETS.items():
        w(os.path.join(ROOT, "permissionsets", f"{api}.permissionset-meta.xml"),
          permset_xml(api, label, desc, rules, SCHEMA))

    nfields = sum(len(o["fields"]) for o in SCHEMA)
    print(f"Generated {len(SCHEMA)} objects, {nfields} fields, {len(PERMSETS)} permission sets.")


if __name__ == "__main__":
    main()
