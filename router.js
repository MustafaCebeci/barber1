// router.js
// Tüm tablolar için REST endpointleri burada toplanır.

const express = require("express");
const { AuthControllers, BookingControllers, ScopedControllers } = require("./controllers");
const { sseHandler } = require("./sse");

const router = express.Router();

/**
 * AUTH
 */
router.post("/auth/login", AuthControllers.login);
router.post("/auth/verify", AuthControllers.verify);
router.get("/auth/me", AuthControllers.me);
router.post("/auth/logout", AuthControllers.logout);

router.post("/appointments/book", BookingControllers.book);
router.get("/appointments/stream", sseHandler);
router.post("/appointments/can-book", BookingControllers.canBook);
router.post("/appointments/available-slots", BookingControllers.getAvailableSlots);
router.post("/appointments/success-details", BookingControllers.successDetails);
router.post("/appointments/success-details-all", BookingControllers.successDetailsAll);
router.post("/appointments/cancel", BookingControllers.cancel);
router.get("/appointments/panel", BookingControllers.panelList);
router.get("/appointments/panel/:id", BookingControllers.panelGetById);
router.post("/appointments/panel/create", BookingControllers.panelCreate);
router.post("/appointments/panel/create-direct", BookingControllers.panelCreateDirect);
router.post("/appointments/panel/status", BookingControllers.panelSetStatus);
router.put("/appointments/:id", BookingControllers.appointmentUpdate);
router.post("/customers/blacklist", BookingControllers.blacklistCustomer);
router.get("/customers/blacklist", BookingControllers.blacklistList);
router.post("/customers/blacklist/remove", BookingControllers.blacklistRemove);
router.get("/customers/flags/:customerId", BookingControllers.customerFlags);
router.get("/customers/stats", BookingControllers.customerStats);
router.post("/appointments/report-month", BookingControllers.reportMonth);

// Scoped (read-only / limited) routes
// Not: personal_db.sql tek işletme tabanlı olduğu için:
// - business_id/branch_id gerçek tablolardan değil, app_settings'dan gelen yapay değerler
// - Endpoint isimleri frontend uyumu için eski isimleri koruyor (compat layer)

router.get("/businesses/current", ScopedControllers.businessesCurrent);
router.get("/businesses", ScopedControllers.businessesList);
router.get("/businesses/:id", ScopedControllers.businessesGet);
router.get("/branches/current", ScopedControllers.branchesCurrent);
router.get("/branches/:id", ScopedControllers.branchesGet);
router.get("/staff", ScopedControllers.staffList);
router.get("/services", ScopedControllers.servicesList);

// staff_services -> provider_services (personal_db)
router.get("/provider_services", ScopedControllers.staffServicesList);
router.post("/provider_services/by-provider", ScopedControllers.servicesByProvider);
router.post("/provider_services/assign", ScopedControllers.staffServicesAssign);
router.post("/provider_services/unassign", ScopedControllers.staffServicesUnassign);

// Geriye uyumluluk için eski endpoint isimleri de çalışsın
router.get("/staff_services", ScopedControllers.staffServicesList);
router.post("/staff_services/assign", ScopedControllers.staffServicesAssign);
router.post("/staff_services/unassign", ScopedControllers.staffServicesUnassign);

router.post("/customers", ScopedControllers.customerCreate);
router.get("/appointments", ScopedControllers.appointmentsList);

// closures -> branch_closures (personal_db)
router.get("/closures", ScopedControllers.branchClosuresList);
router.post("/closures", ScopedControllers.branchClosuresCreate);
router.post("/closures/reopen-today", ScopedControllers.branchClosuresReopenToday);
router.get("/closures/today", ScopedControllers.branchClosuresTodayPublic);

// Geriye uyumluluk için eski isimler de çalışsın
router.get("/branch_closures", ScopedControllers.branchClosuresList);
router.post("/branch_closures", ScopedControllers.branchClosuresCreate);
router.post("/branch_closures/reopen-today", ScopedControllers.branchClosuresReopenToday);
router.get("/branch_closures/today", ScopedControllers.branchClosuresTodayPublic);

router.put("/businesses/:id/settings", ScopedControllers.businessSettingsUpdate);
router.post("/services", ScopedControllers.servicesCreate);
router.put("/services/:id", ScopedControllers.servicesUpdate);
router.post("/staff", ScopedControllers.staffCreate);
router.put("/staff/:id", ScopedControllers.staffUpdate);

// staff_accounts -> branch_accounts (personal_db)
router.get("/staff_accounts", ScopedControllers.branchAccountsList);
router.post("/staff_accounts", ScopedControllers.branchAccountsCreate);
router.put("/staff_accounts/:id", ScopedControllers.branchAccountsUpdate);
router.delete("/staff_accounts/:id", ScopedControllers.branchAccountsRemove);

// Geriye uyumluluk için eski isimler de çalışsın
router.get("/branch_accounts", ScopedControllers.branchAccountsList);
router.post("/branch_accounts", ScopedControllers.branchAccountsCreate);
router.put("/branch_accounts/:id", ScopedControllers.branchAccountsUpdate);
router.delete("/branch_accounts/:id", ScopedControllers.branchAccountsRemove);

router.delete("/staff/:id", ScopedControllers.staffRemove);

// Service Providers CRUD (personal_db provider system)
router.get("/service_providers", ScopedControllers.providersList);
router.post("/service_providers", ScopedControllers.providersCreate);
router.put("/service_providers/:id", ScopedControllers.providersUpdate);
router.delete("/service_providers/:id", ScopedControllers.providersRemove);

module.exports = router;
