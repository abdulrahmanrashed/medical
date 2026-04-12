using Doctors.Application.DTOs.Appointments;
using Doctors.Domain.Common;

namespace Doctors.Application.Common.Interfaces;

public interface IAppointmentService
{
    Task<PagedAppointmentsDto> GetPageForCurrentUserAsync(
        int? doctorId = null,
        int pageNumber = 1,
        int pageSize = 10,
        DateTime? scheduledFromUtc = null,
        DateTime? scheduledToUtc = null,
        CancellationToken cancellationToken = default);

    Task<AppointmentDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<AppointmentDto> CreateAsync(CreateAppointmentDto dto, CancellationToken cancellationToken = default);
    Task<AppointmentDto> UpdateAsync(int id, UpdateAppointmentDto dto, CancellationToken cancellationToken = default);
    Task<AppointmentDto> UpdateStatusByDoctorAsync(int id, AppointmentStatus newStatus, CancellationToken cancellationToken = default);
    Task<AppointmentDto> UpdateSessionByDoctorAsync(int id, DoctorUpdateAppointmentSessionDto dto, CancellationToken cancellationToken = default);

    Task<AppointmentDto> ReplaceAppointmentPrescriptionsAsync(
        int id,
        ReplaceAppointmentPrescriptionsDto dto,
        CancellationToken cancellationToken = default);

    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
