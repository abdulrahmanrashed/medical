namespace Doctors.Application.DTOs.Appointments;

public class PagedAppointmentsDto
{
    public IReadOnlyList<AppointmentDto> Items { get; set; } = Array.Empty<AppointmentDto>();
    public int TotalCount { get; set; }
    public int PageNumber { get; set; }
    public int PageSize { get; set; }
    public int TotalPages => PageSize <= 0 ? 0 : (int)Math.Ceiling(TotalCount / (double)PageSize);
}
