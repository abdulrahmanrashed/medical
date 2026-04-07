using Doctors.Application.DTOs.Doctors;

namespace Doctors.Application.Common.Interfaces;

public interface IDoctorService
{
    Task<IReadOnlyList<DoctorDto>> GetByClinicAsync(int clinicId, CancellationToken cancellationToken = default);
    Task<DoctorDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<DoctorDto?> GetMineAsync(CancellationToken cancellationToken = default);
    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
