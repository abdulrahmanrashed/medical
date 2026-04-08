using Doctors.Application.DTOs.Schedules;

namespace Doctors.Application.Common.Interfaces;

public interface IDoctorWorkScheduleService
{
    Task<IReadOnlyList<DoctorWorkScheduleDto>> GetByClinicAsync(
        int clinicId,
        int? doctorId,
        DateOnly? from,
        DateOnly? to,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<DoctorWorkScheduleDto>> BulkUpsertAsync(
        int clinicId,
        BulkDoctorWorkScheduleRequestDto dto,
        CancellationToken cancellationToken = default);

    Task<DoctorWorkScheduleDto> UpdateAsync(
        int id,
        UpdateDoctorWorkScheduleDto dto,
        CancellationToken cancellationToken = default);

    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
