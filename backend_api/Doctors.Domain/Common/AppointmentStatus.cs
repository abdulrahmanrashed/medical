namespace Doctors.Domain.Common;

public enum AppointmentStatus
{
    Pending = 0,
    Approved = 1,
    Rescheduled = 2,
    Cancelled = 3,
    Completed = 4,
    /// <summary>Doctor has started the visit; shown as live on the doctor queue until completed.</summary>
    InProgress = 5
}
