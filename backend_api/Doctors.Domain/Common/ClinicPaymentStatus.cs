namespace Doctors.Domain.Common;



/// <summary>

/// Unpaid clinics cannot use Doctor or Reception staff accounts (login + API blocked).

/// ClinicAdmin may still sign in to manage payment contact with the system admin.

/// </summary>

public enum ClinicPaymentStatus

{

    Unpaid = 0,

    Paid = 1

}

