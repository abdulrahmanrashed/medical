using Doctors.Application.DTOs.Clinics;
using Doctors.Domain.Common;

namespace Doctors.Application.Common.Interfaces;

public interface IClinicService
{
    /// <param name="search">Optional: case-insensitive match on clinic name or email.</param>
    Task<IReadOnlyList<ClinicDto>> GetAllAsync(string? search = null, CancellationToken cancellationToken = default);

    Task<ClinicDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<ClinicDto> CreateAsync(CreateClinicDto dto, CancellationToken cancellationToken = default);
    Task<ClinicDto> UpdateAsync(int id, UpdateClinicDto dto, CancellationToken cancellationToken = default);
    Task<ClinicDto> SetPaymentStatusAsync(int id, ClinicPaymentStatus status, CancellationToken cancellationToken = default);

    /// <summary>Records a payment, updates balances and subscription end date, appends <see cref="ClinicInvoiceDto"/>.</summary>
    Task<ClinicDto> RecordPaymentAsync(int clinicId, RecordClinicPaymentDto dto, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ClinicInvoiceDto>> GetInvoicesAsync(int clinicId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ClinicInvoiceListItemDto>> GetAllInvoicesAsync(CancellationToken cancellationToken = default);

    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
