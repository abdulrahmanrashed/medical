using AutoMapper;
using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Clinics;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Application.Services;

public class ClinicService : IClinicService
{
    private readonly IRepository<Clinic> _clinics;
    private readonly IRepository<ClinicInvoice> _invoices;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IClinicAdminProvisioner _clinicAdminProvisioner;
    private readonly IClinicOwnerLookup _clinicOwnerLookup;

    public ClinicService(
        IRepository<Clinic> clinics,
        IRepository<ClinicInvoice> invoices,
        IUnitOfWork unitOfWork,
        IMapper mapper,
        IClinicAdminProvisioner clinicAdminProvisioner,
        IClinicOwnerLookup clinicOwnerLookup)
    {
        _clinics = clinics;
        _invoices = invoices;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _clinicAdminProvisioner = clinicAdminProvisioner;
        _clinicOwnerLookup = clinicOwnerLookup;
    }

    public async Task<IReadOnlyList<ClinicDto>> GetAllAsync(string? search = null, CancellationToken cancellationToken = default)
    {
        var query = _clinics.Query()
            .Include(c => c.Doctors)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim();
            query = query.Where(c =>
                c.Name.Contains(s)
                || (c.Email != null && c.Email.Contains(s)));
        }

        var list = await query
            .OrderBy(c => c.Name)
            .ToListAsync(cancellationToken);
        var dtos = _mapper.Map<List<ClinicDto>>(list);
        await EnrichOwnerFieldsAsync(list, dtos, cancellationToken);
        return dtos;
    }

    public async Task<ClinicDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var clinic = await _clinics.Query()
            .Include(c => c.Doctors)
            .FirstOrDefaultAsync(c => c.Id == id, cancellationToken);
        if (clinic is null)
            throw new NotFoundException($"Clinic {id} was not found.");
        var dto = _mapper.Map<ClinicDto>(clinic);
        await EnrichOwnerFieldsAsync(new List<Clinic> { clinic }, new List<ClinicDto> { dto }, cancellationToken);
        return dto;
    }

    public async Task<ClinicDto> CreateAsync(CreateClinicDto dto, CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        if (dto.PaidAmount > dto.TotalAmount)
            throw new BadRequestAppException("PaidAmount cannot exceed TotalAmount.");

        var entity = new Clinic
        {
            Name = dto.Name,
            Address = dto.Address,
            Phone = dto.Phone,
            Email = dto.Email,
            TotalAmount = dto.TotalAmount,
            PaidAmount = dto.PaidAmount,
            RemainingAmount = Math.Max(0, dto.TotalAmount - dto.PaidAmount),
            SubscriptionEndDate = NormalizeToUtcOptional(dto.SubscriptionEndDate),
            PaymentStatus = ClinicPaymentStatus.Unpaid,
            SubscriptionStartDate = now,
            CreatedAtUtc = now,
            LastPaymentDate = dto.PaidAmount > 0 ? now : null
        };
        entity.PaymentStatus = ResolvePaymentStatusAfterMutation(entity, now);

        await _clinics.AddAsync(entity, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        if (dto.PaidAmount > 0)
        {
            var nextExpiry = entity.SubscriptionEndDate ?? now;
            var invoice = new ClinicInvoice
            {
                ClinicId = entity.Id,
                AmountPaid = dto.PaidAmount,
                PaymentDate = now,
                NextExpiryDate = nextExpiry,
                CreatedAtUtc = now
            };
            await _invoices.AddAsync(invoice, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
        }

        await _clinicAdminProvisioner.CreateAndLinkClinicAdminAsync(
            entity.Id,
            dto.ClinicAdminEmail.Trim(),
            dto.ClinicAdminPassword,
            dto.ClinicAdminFirstName.Trim(),
            dto.ClinicAdminLastName.Trim(),
            cancellationToken);

        return await GetByIdAsync(entity.Id, cancellationToken);
    }

    public async Task<ClinicDto> SetPaymentStatusAsync(int id, ClinicPaymentStatus status, CancellationToken cancellationToken = default)
    {
        var clinic = await _clinics.GetByIdAsync(id, cancellationToken);
        if (clinic is null)
            throw new NotFoundException($"Clinic {id} was not found.");
        clinic.PaymentStatus = status;
        clinic.UpdatedAtUtc = DateTime.UtcNow;
        if (status == ClinicPaymentStatus.Paid)
        {
            clinic.LastPaymentDate = DateTime.UtcNow;
            clinic.SubscriptionOverdueNotifiedAtUtc = null;
        }
        _clinics.Update(clinic);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task<ClinicDto> RecordPaymentAsync(int clinicId, RecordClinicPaymentDto dto, CancellationToken cancellationToken = default)
    {
        if (dto.AmountPaid <= 0)
            throw new BadRequestAppException("AmountPaid must be greater than zero.");

        var clinic = await _clinics.GetByIdAsync(clinicId, cancellationToken);
        if (clinic is null)
            throw new NotFoundException($"Clinic {clinicId} was not found.");

        var paymentDate = NormalizeToUtcOptional(dto.PaymentDate) ?? DateTime.UtcNow;
        var nextExpiry = NormalizeToUtcRequired(dto.NextExpiryDate);

        clinic.PaidAmount += dto.AmountPaid;
        clinic.RecalculateRemainingAmount();
        clinic.LastPaymentDate = paymentDate;
        clinic.SubscriptionEndDate = nextExpiry;
        clinic.SubscriptionOverdueNotifiedAtUtc = null;
        clinic.UpdatedAtUtc = DateTime.UtcNow;
        clinic.PaymentStatus = ResolvePaymentStatusAfterMutation(clinic, DateTime.UtcNow);

        var invoice = new ClinicInvoice
        {
            ClinicId = clinicId,
            AmountPaid = dto.AmountPaid,
            PaymentDate = paymentDate,
            NextExpiryDate = nextExpiry,
            CreatedAtUtc = DateTime.UtcNow
        };

        await _invoices.AddAsync(invoice, cancellationToken);
        _clinics.Update(clinic);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(clinicId, cancellationToken);
    }

    public async Task<IReadOnlyList<ClinicInvoiceDto>> GetInvoicesAsync(int clinicId, CancellationToken cancellationToken = default)
    {
        var exists = await _clinics.Query().AnyAsync(c => c.Id == clinicId, cancellationToken);
        if (!exists)
            throw new NotFoundException($"Clinic {clinicId} was not found.");

        var rows = await _invoices.Query()
            .Where(i => i.ClinicId == clinicId)
            .OrderByDescending(i => i.PaymentDate)
            .ThenByDescending(i => i.Id)
            .ToListAsync(cancellationToken);
        return _mapper.Map<IReadOnlyList<ClinicInvoiceDto>>(rows);
    }

    public async Task<IReadOnlyList<ClinicInvoiceListItemDto>> GetAllInvoicesAsync(CancellationToken cancellationToken = default)
    {
        var rows = await _invoices.Query()
            .AsNoTracking()
            .Include(i => i.Clinic)
            .OrderByDescending(i => i.PaymentDate)
            .ThenByDescending(i => i.Id)
            .ToListAsync(cancellationToken);
        return rows.Select(i => new ClinicInvoiceListItemDto
        {
            InvoiceId = i.Id,
            ClinicId = i.ClinicId,
            ClinicName = i.Clinic.Name,
            AmountPaid = i.AmountPaid,
            TotalAmount = i.Clinic.TotalAmount,
            ClinicPaidAmount = i.Clinic.PaidAmount,
            RemainingAmount = i.Clinic.RemainingAmount,
            PaymentDate = i.PaymentDate,
            NextExpiryDate = i.NextExpiryDate
        }).ToList();
    }

    public async Task<ClinicDto> UpdateAsync(int id, UpdateClinicDto dto, CancellationToken cancellationToken = default)
    {
        var clinic = await _clinics.GetByIdAsync(id, cancellationToken);
        if (clinic is null)
            throw new NotFoundException($"Clinic {id} was not found.");
        clinic.Name = dto.Name;
        clinic.Address = dto.Address;
        clinic.Phone = dto.Phone;
        clinic.Email = dto.Email;
        clinic.UpdatedAtUtc = DateTime.UtcNow;
        _clinics.Update(clinic);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var clinic = await _clinics.Query()
            .Include(c => c.Doctors)
            .FirstOrDefaultAsync(c => c.Id == id, cancellationToken);
        if (clinic is null)
            throw new NotFoundException($"Clinic {id} was not found.");
        if (clinic.Doctors.Count > 0)
            throw new BadRequestAppException("Cannot delete a clinic that still has doctors assigned.");
        _clinics.Remove(clinic);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    private static ClinicPaymentStatus ResolvePaymentStatusAfterMutation(Clinic c, DateTime nowUtc)
    {
        if (c.RemainingAmount <= 0)
            return ClinicPaymentStatus.Paid;
        if (c.SubscriptionEndDate.HasValue && c.SubscriptionEndDate.Value > nowUtc)
            return ClinicPaymentStatus.Paid;
        return ClinicPaymentStatus.Unpaid;
    }

    private static DateTime? NormalizeToUtcOptional(DateTime? dt)
    {
        if (dt is null) return null;
        var v = dt.Value;
        return v.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(v, DateTimeKind.Utc)
            : v.ToUniversalTime();
    }

    private static DateTime NormalizeToUtcRequired(DateTime dt)
    {
        return dt.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(dt, DateTimeKind.Utc)
            : dt.ToUniversalTime();
    }

    private async Task EnrichOwnerFieldsAsync(
        IReadOnlyList<Clinic> entities,
        IReadOnlyList<ClinicDto> dtos,
        CancellationToken cancellationToken)
    {
        if (entities.Count == 0 || dtos.Count != entities.Count)
            return;

        var userIds = entities
            .Select(e => e.ClinicAdminUserId)
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Cast<string>()
            .Distinct()
            .ToList();

        var owners = await _clinicOwnerLookup.GetByUserIdsAsync(userIds, cancellationToken);

        for (var i = 0; i < entities.Count; i++)
        {
            var uid = entities[i].ClinicAdminUserId;
            if (string.IsNullOrWhiteSpace(uid) || !owners.TryGetValue(uid, out var o))
                continue;

            var full = $"{o.FirstName} {o.LastName}".Trim();
            dtos[i].OwnerFullName = string.IsNullOrEmpty(full) ? null : full;
            dtos[i].OwnerEmail = o.Email;
        }
    }
}
