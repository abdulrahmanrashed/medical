using Doctors.Application.DTOs.Appointments;
using Doctors.Domain.Common;

namespace Doctors.Application.Common.Interfaces;

public interface IAppointmentService
{
    Task<IReadOnlyList<AppointmentDto>> GetAllForCurrentUserAsync(int? doctorId = null, CancellationToken cancellationToken = default);
    Task<AppointmentDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<AppointmentDto> CreateAsync(CreateAppointmentDto dto, CancellationToken cancellationToken = default);
    Task<AppointmentDto> UpdateAsync(int id, UpdateAppointmentDto dto, CancellationToken cancellationToken = default);
    Task<AppointmentDto> UpdateStatusByDoctorAsync(int id, AppointmentStatus newStatus, CancellationToken cancellationToken = default);
    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
