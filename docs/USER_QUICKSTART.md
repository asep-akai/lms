# User quick start

LMS shows tools according to your organization membership and permissions. Two
people may see different navigation even when they belong to the same
organization.

## Sign in

Organization users sign in at `/users/sign_in`. Platform administrators use the
separate `/console/login` page.

If you belong to one active organization, LMS opens it after sign-in. If you
belong to several, choose the organization you want to enter.

All displayed dates and times use Western Indonesian Time (WIB, Asia/Jakarta).

## Student guide

### Courses and progress

Open **Courses** to see your enrollments and completion percentage. A course is
divided into collapsible sections containing materials and quizzes.

- Open a material, read or watch its content, then use the completion control
  between the previous and next module buttons. You can clear the completed
  state if needed.
- Open a quiz from its course card. The connection check runs before the first
  attempt. A warning does not prevent you from continuing.
- Quiz answers save when you move between questions, use the numbered
  navigation, or leave through the quiz back control.
- A timed quiz keeps counting down while you are away. LMS submits the attempt
  after its deadline.
- A published result appears under **Evaluation**. It includes the score,
  question review, answer key where applicable, and grader feedback.
- Published certificates appear under **Certificates** and can be downloaded as
  PDF files.

### Assignments

Open **Assignments** to see assigned work and its WIB deadline. An assignment
may accept written text, uploaded documents, or both. Review the submission
before selecting **Submit** because submitted work cannot be changed. Teacher
comments appear on the assignment and generate a notification.

### Classes

Open **Classes** to use the monthly calendar. Select a date to see its classes,
or open class history for earlier sessions. Online classes include their
meeting link when the scheduler provided one.

A student may request a reschedule when all of these conditions are true:

- The class has one student.
- The class starts more than 24 hours from now.
- The student has remaining reschedule quota.

The request cancels that class occurrence and notifies its teacher. After a
class starts, the student can leave one rating and an optional comment for the
teacher.

### Messages, notifications, and support

Open **Messages** to contact teachers or students connected to you through a
class. Unread conversations have a visible marker. New messages appear in an
open conversation without a manual reload.

The bell in the top bar shows unread notifications for classes, quiz results,
certificates, assignments, messages, and support updates. Open a notification
to visit the relevant record.

Use **Support** to create a ticket when an organization administrator needs to
help. Replies remain attached to the ticket.

## Teacher guide

Teachers can use **Classes** to view their calendar, meeting details, and class
history. After a class starts, a teacher can record internal notes, feedback for
students, topics discussed, and next topics. Students can see the feedback
addressed to them but not the teacher's internal notes.

Use **Students** to see students with whom you have classes. A student's page
collects course progress, quiz attempts, and published certificates. Teachers
with assignment permissions can create an assignment from the assignment page
or from a student's page.

When a student submits an assignment, LMS sends the teacher an email and an
in-app notification. Open the assignment to review the submission and leave a
comment. Teachers can also use **Messages**, the notification bell, and
**Support**.

## Organization administrator guide

Organization administrators can manage the tenant according to their granted
permissions:

- **Users** creates memberships, assigns organization roles, changes member
  status, and replaces passwords without revealing the current password.
- **Students** manages course enrollment and reschedule quota, and inspects
  course progress by module.
- **Courses** creates courses, sections, materials, quizzes, and enrollments.
- **Classes** schedules onsite or online meetings and assigns teachers and
  students.
- **Assignments** creates and reviews assigned work.
- **Grading** lists quiz attempts by status. Reviewers can grade manually or
  generate an AI-assisted draft, adjust individual results, add feedback, and
  publish the result.
- **Certificates** lists generated certificates. Unpublishing a certificate
  hides it from the student while keeping its record.
- **Roles** manages organization roles and organization-specific permissions.
  Console permissions are not visible here.
- **Audit log** records significant administrative activity.
- **Support** manages organization tickets and can escalate a ticket to the
  platform console.

The built-in Organization administrator role is protected. Only an existing
organization administrator can grant or remove that role, and the organization
must retain an active administrator.

## Platform administrator guide

Sign in through `/console/login`. The console manages installation-level
organizations, application users, console administrators, console roles, and
escalated support tickets.

Console accounts and organization memberships are separate identities. A
console role cannot receive organization-specific permissions, and a console
administrator does not automatically gain access to tenant content.

## Development email preview

In a local Docker environment, open <http://localhost:8025> to inspect account,
class, assignment, and support emails. Mailpit captures these messages instead
of sending them to real recipients.
