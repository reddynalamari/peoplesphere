import { LightningElement } from 'lwc';

export default class PsPublicDemo extends LightningElement {
    modules = [
        { icon: 'utility:flow', title: 'Onboarding orchestrator', text: 'Template-driven checklists across HR, IT, Finance, Manager and the new joiner, with document verification.' },
        { icon: 'utility:people', title: 'Employee 360°', text: 'Profile, lifecycle stage, unified timeline, skills gap and risk indicators in one view.' },
        { icon: 'utility:education', title: 'Learning management', text: 'Mandatory and role-based assignment, prerequisites, server-graded quizzes and expiring certifications.' },
        { icon: 'utility:favorite', title: 'Performance & goals', text: 'OKRs aligned from company to individual, self and manager reviews, calibration and promotion flags.' },
        { icon: 'utility:clock', title: 'Attendance & leave', text: 'Check-in with late detection, working-day leave calculation, balances and manager approvals.' },
        { icon: 'utility:service_contract', title: 'HR service desk', text: 'Automatic categorisation, priority detection, SLA tracking, least-loaded routing and escalation.' },
        { icon: 'utility:work_order_type', title: 'Recruitment & mobility', text: 'Requisitions, skill-match scoring, interviews, hire-to-onboarding conversion and an internal job marketplace.' },
        { icon: 'utility:logout', title: 'Exit management', text: 'Coordinated clearance, asset recovery, pending expenses and final settlement.' },
        { icon: 'utility:like', title: 'Engagement', text: 'Anonymous eNPS pulses, recognition wall with points, announcements and celebrations.' },
        { icon: 'utility:sparkles', title: 'AI HR assistant', text: 'Natural-language workforce analytics and a policy copilot, with optional Claude integration.' },
        { icon: 'utility:shield', title: 'Compliance control centre', text: 'Policy acknowledgements, expiring documents and certifications, audit history.' },
        { icon: 'utility:chart', title: 'Workforce analytics', text: 'Headcount, attrition, hiring funnel, learning, performance distribution and cost (HR only).' }
    ];
}
