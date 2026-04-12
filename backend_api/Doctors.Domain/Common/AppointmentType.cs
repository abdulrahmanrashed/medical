namespace Doctors.Domain.Common;

public enum AppointmentType
{
    General = 0,
    SpecificDoctor = 1,
    /// <summary>Obstetric follow-up; specialized vitals stored in appointment SpecializedDataJson.</summary>
    PregnancyFollowUp = 2,
    /// <summary>Diabetes care; A1C / weight in specialized JSON.</summary>
    Diabetes = 3
}
