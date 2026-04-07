using AutoMapper;
using Doctors.Application.DTOs.Appointments;
using Doctors.Application.DTOs.Clinics;
using Doctors.Application.DTOs.MedicalRecords;
using Doctors.Application.DTOs.Notifications;
using Doctors.Application.DTOs.Patients;
using Doctors.Domain.Entities;

namespace Doctors.Application.Mapping;

public class MappingProfile : Profile
{
    public MappingProfile()
    {
        CreateMap<Clinic, ClinicDto>()
            .ForMember(d => d.DoctorCount, o => o.MapFrom(s => s.Doctors.Count))
            .ForMember(d => d.PaymentStatus, o => o.MapFrom(s => s.PaymentStatus))
            .ForMember(d => d.SubscriptionStartDate, o => o.MapFrom(s => s.SubscriptionStartDate))
            .ForMember(d => d.LastPaymentDate, o => o.MapFrom(s => s.LastPaymentDate))
            .ForMember(d => d.DaysSinceLastPaymentReference, o => o.MapFrom(s => s.GetDaysSinceLastPaymentReference(null)))
            .ForMember(d => d.SubscriptionStatus, o => o.MapFrom(s => s.GetSubscriptionStatus(null)));

        CreateMap<Patient, PatientDto>()
            .ForMember(d => d.ClinicIds, o => o.MapFrom(s => s.PatientClinics.Select(pc => pc.ClinicId).ToList()));

        CreateMap<Appointment, AppointmentDto>()
            .ForMember(d => d.ClinicName, o => o.MapFrom(s => s.Clinic.Name))
            .ForMember(d => d.DoctorName, o => o.Ignore())
            .ForMember(d => d.PatientName, o => o.MapFrom(s => s.PatientName))
            // EF often returns Unspecified; force UTC so JSON includes "Z" and clients parse as UTC.
            .ForMember(d => d.ScheduledAtUtc,
                o => o.MapFrom(s => DateTime.SpecifyKind(s.ScheduledAtUtc, DateTimeKind.Utc)))
            .ForMember(d => d.CreatedAtUtc,
                o => o.MapFrom(s => DateTime.SpecifyKind(s.CreatedAtUtc, DateTimeKind.Utc)))
            .ForMember(d => d.UpdatedAtUtc,
                o => o.MapFrom(s => s.UpdatedAtUtc == null
                    ? (DateTime?)null
                    : DateTime.SpecifyKind(s.UpdatedAtUtc.Value, DateTimeKind.Utc)));

        CreateMap<MedicalRecord, MedicalRecordDto>()
            .ForMember(d => d.PatientName, o => o.MapFrom(s => s.Patient.FullName))
            .ForMember(d => d.DoctorName, o => o.Ignore())
            .ForMember(d => d.Prescriptions, o => o.MapFrom(s => s.Prescriptions))
            .ForMember(d => d.Attachments, o => o.MapFrom(s => s.Attachments));

        CreateMap<Prescription, PrescriptionSummaryDto>()
            .ForMember(d => d.Medications, o => o.MapFrom(s => s.Medications))
            // PatientId is set in MedicalRecordService.MapRecordAsync (avoid ThenInclude back to MedicalRecord).
            .ForMember(d => d.PatientId, o => o.Ignore())
            .ForMember(d => d.DoctorId, o => o.MapFrom(s => s.DoctorId));

        CreateMap<Medication, MedicationDto>();
        CreateMap<FileAttachment, FileAttachmentDto>();
        CreateMap<Notification, NotificationDto>();
    }
}
