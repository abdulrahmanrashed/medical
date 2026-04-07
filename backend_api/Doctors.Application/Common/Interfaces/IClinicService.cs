using Doctors.Application.DTOs.Clinics;
using Doctors.Domain.Common;

namespace Doctors.Application.Common.Interfaces;

public interface IClinicService
{
    Task<IReadOnlyList<ClinicDto>> GetAllAsync(CancellationToken cancellationToken = default);
    Task<ClinicDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<ClinicDto> CreateAsync(CreateClinicDto dto, CancellationToken cancellationToken = default);
    Task<ClinicDto> UpdateAsync(int id, UpdateClinicDto dto, CancellationToken cancellationToken = default);
    Task<ClinicDto> SetPaymentStatusAsync(int id, ClinicPaymentStatus status, CancellationToken cancellationToken = default);
    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
