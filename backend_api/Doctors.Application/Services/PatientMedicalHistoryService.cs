using AutoMapper;
using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Appointments;
using Doctors.Application.DTOs.Patients;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Application.Services;

public class PatientMedicalHistoryService : IPatientMedicalHistoryService
{
    private readonly IRepository<MedicalRecord> _records;
    private readonly IRepository<AppointmentPrescription> _appointmentPrescriptions;
    private readonly IRepository<Appointment> _appointments;
    private readonly ICurrentUserService _currentUser;
    private readonly IMapper _mapper;
    private readonly IMedicalFileService _medicalFileService;

    public PatientMedicalHistoryService(
        IRepository<MedicalRecord> records,
        IRepository<AppointmentPrescription> appointmentPrescriptions,
        IRepository<Appointment> appointments,
        ICurrentUserService currentUser,
        IMapper mapper,
        IMedicalFileService medicalFileService)
    {
        _records = records;
        _appointmentPrescriptions = appointmentPrescriptions;
        _appointments = appointments;
        _currentUser = currentUser;
        _mapper = mapper;
        _medicalFileService = medicalFileService;
    }

    public async Task<PatientMedicalHistoryDto> GetMyMedicalHistoryAsync(CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Patient))
            throw new ForbiddenException("Only patients can load medical history.");

        var patientId = _currentUser.GetPatientId()
            ?? throw new ForbiddenException("Patient profile was not found for the current user.");

        var latestRecord = await _records.Query()
            .Where(r => r.PatientId == patientId)
            .OrderByDescending(r => r.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        var latestRequestedTests = await _appointments.Query()
            .Where(a => a.PatientId == patientId
                        && a.RequestedTests != null
                        && a.RequestedTests.Trim() != string.Empty)
            .OrderByDescending(a => a.ScheduledAtUtc)
            .Select(a => a.RequestedTests)
            .FirstOrDefaultAsync(cancellationToken);

        var now = DateTime.UtcNow;
        var activePresc = await _appointmentPrescriptions.Query()
            .Include(p => p.Appointment)
            .Where(p => p.Appointment.PatientId == patientId)
            .Where(p => p.StartDateUtc <= now
                        && (p.EndDateUtc == null || p.EndDateUtc >= now.Date))
            .OrderByDescending(p => p.StartDateUtc)
            .ToListAsync(cancellationToken);

        var files = await _medicalFileService.GetMineAsync(cancellationToken);

        return new PatientMedicalHistoryDto
        {
            CurrentDiagnosis = latestRecord?.Diagnosis,
            CurrentClinicalNotes = latestRecord?.Notes,
            LatestMedicalRecordAtUtc = latestRecord?.CreatedAtUtc,
            RequestedTests = latestRequestedTests,
            ActiveAppointmentPrescriptions = _mapper.Map<List<AppointmentPrescriptionDto>>(activePresc),
            MedicalFiles = files.ToList()
        };
    }
}
