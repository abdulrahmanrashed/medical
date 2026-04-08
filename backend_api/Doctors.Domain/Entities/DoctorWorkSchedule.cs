using Doctors.Domain.Common;

namespace Doctors.Domain.Entities;

/// <summary>One row per doctor per calendar day (shift or day off).</summary>
public class DoctorWorkSchedule : BaseEntity
{
    public int DoctorId { get; set; }
    public Doctor Doctor { get; set; } = null!;

    /// <summary>Calendar date of the shift (UTC date stored; compare using date-only).</summary>
    public DateOnly ShiftDate { get; set; }

    public TimeOnly? StartTime { get; set; }
    public TimeOnly? EndTime { get; set; }

    public string? Notes { get; set; }
    public ScheduleShiftStatus Status { get; set; }
}
