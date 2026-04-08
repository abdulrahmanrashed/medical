using Doctors.Domain.Common;

namespace Doctors.Application.DTOs.Schedules;

public class DoctorWorkScheduleDto
{
    public int Id { get; set; }
    public int DoctorId { get; set; }
    public string DoctorFirstName { get; set; } = string.Empty;
    public string DoctorLastName { get; set; } = string.Empty;
    public DateOnly ShiftDate { get; set; }
    public TimeOnly? StartTime { get; set; }
    public TimeOnly? EndTime { get; set; }
    public string? Notes { get; set; }
    public ScheduleShiftStatus Status { get; set; }
}

public enum ScheduleBulkMode
{
    Daily = 0,
    /// <summary>7 consecutive days starting at RangeStart (inclusive).</summary>
    Weekly = 1
}

public class BulkDoctorWorkScheduleRequestDto
{
    public int DoctorId { get; set; }
    public ScheduleBulkMode Mode { get; set; }

    public DateOnly? SingleDate { get; set; }

    /// <summary>First day of the week block for Weekly mode; 7 days are applied (this day through +6).</summary>
    public DateOnly? RangeStart { get; set; }

    public ScheduleShiftStatus Status { get; set; }
    public TimeOnly? StartTime { get; set; }
    public TimeOnly? EndTime { get; set; }
    public string? Notes { get; set; }
}

public class UpdateDoctorWorkScheduleDto
{
    public DateOnly ShiftDate { get; set; }
    public ScheduleShiftStatus Status { get; set; }
    public TimeOnly? StartTime { get; set; }
    public TimeOnly? EndTime { get; set; }
    public string? Notes { get; set; }
}
