import Foundation
import Testing
@testable import Trio

/// Unit tests for `AutoISFsmb` — the autoISF 3.01 SMB-control logic
/// (`loop_smb()` enable/disable + `determine_varSMBratio()` ramp +
/// iobTH gate / 130 % overrun cap + smb_max_range_extension).
@Suite("AutoISFsmb Tests") struct AutoISFsmbTests {
    private func makeProfile(
        autoisf: Bool = true,
        enableSMBEvenOnOddOffAlways: Bool = true,
        maxIob: Decimal = 10,
        iobThresholdPercent: Decimal = 1,
        smbDeliveryRatio: Decimal = 0.5,
        smbDeliveryRatioBGrange: Decimal = 0,
        smbDeliveryRatioMin: Decimal = 0.4,
        smbDeliveryRatioMax: Decimal = 0.8,
        smbMaxRangeExtension: Decimal = 1,
        targetUnits: GlucoseUnits = .mgdL
    ) -> Profile {
        var profile = Profile()
        profile.autoisf = autoisf
        profile.enableSMBEvenOnOddOffAlways = enableSMBEvenOnOddOffAlways
        profile.maxIob = maxIob
        profile.iobThresholdPercent = iobThresholdPercent
        profile.smbDeliveryRatio = smbDeliveryRatio
        profile.smbDeliveryRatioBGrange = smbDeliveryRatioBGrange
        profile.smbDeliveryRatioMin = smbDeliveryRatioMin
        profile.smbDeliveryRatioMax = smbDeliveryRatioMax
        profile.smbMaxRangeExtension = smbMaxRangeExtension
        profile.targetUnits = targetUnits
        return profile
    }

    // MARK: - evaluate()

    @Test("evaluate returns nil when autoISF is disabled") func evaluateDisabledReturnsNil() throws {
        let profile = makeProfile(autoisf: false)

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: 100,
            microBolusAllowed: true,
            iob: 0,
            b30IsActive: false,
            exerciseRatio: 1,
            overrideSmbIsOff: false
        )

        #expect(result == nil)
    }

    @Test("evaluate blocks when override disables SMB") func evaluateOverrideBlocks() throws {
        let profile = makeProfile()

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: 100,
            microBolusAllowed: true,
            iob: 0,
            b30IsActive: false,
            exerciseRatio: 1,
            overrideSmbIsOff: true
        )!

        #expect(result.loopMode == .blocked)
        #expect(!result.smbEnabled)
    }

    @Test("evaluate reports b30Running when B30 basal is active") func evaluateB30Running() throws {
        let profile = makeProfile()

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: 100,
            microBolusAllowed: true,
            iob: 0,
            b30IsActive: true,
            exerciseRatio: 1,
            overrideSmbIsOff: false
        )!

        #expect(result.loopMode == .b30Running)
        #expect(!result.smbEnabled)
    }

    @Test("evaluate defers to oref when microBolus is not allowed") func evaluateMicroBolusBlockedFallsToOref() throws {
        let profile = makeProfile()

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: 100,
            microBolusAllowed: false,
            iob: 0,
            b30IsActive: false,
            exerciseRatio: 1,
            overrideSmbIsOff: false
        )!

        #expect(result.loopMode == .oref)
    }

    @Test("evaluate disables SMB when current IOB exceeds the iobTH gate") func evaluateIobTHExceeded() throws {
        // iobThresholdPercent=0.5, maxIob=10 → effective=5; current iob=8 > 5 → blocked
        let profile = makeProfile(iobThresholdPercent: Decimal(string: "0.5")!)

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: 100,
            microBolusAllowed: true,
            iob: 8,
            b30IsActive: false,
            exerciseRatio: 1,
            overrideSmbIsOff: false
        )!

        #expect(result.loopMode == .iobTHExceeded)
        #expect(result.iobTHEffective == 5)
    }

    @Test("evaluate defers to oref when even/odd toggle is off") func evaluateEvenOddToggleOff() throws {
        let profile = makeProfile(enableSMBEvenOnOddOffAlways: false)

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: 101, // odd — would block if toggle were on
            microBolusAllowed: true,
            iob: 0,
            b30IsActive: false,
            exerciseRatio: 1,
            overrideSmbIsOff: false
        )!

        #expect(result.loopMode == .oref)
    }

    @Test("evaluate blocks SMB on odd targets when toggle is on") func evaluateOddTargetBlocks() throws {
        let profile = makeProfile()

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: 101,
            microBolusAllowed: true,
            iob: 0,
            b30IsActive: false,
            exerciseRatio: 1,
            overrideSmbIsOff: false
        )!

        #expect(result.loopMode == .blocked)
    }

    @Test("evaluate blocks when maxIob is zero") func evaluateMaxIobZeroBlocks() throws {
        let profile = makeProfile(maxIob: 0)

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: 100,
            microBolusAllowed: true,
            iob: 0,
            b30IsActive: false,
            exerciseRatio: 1,
            overrideSmbIsOff: false
        )!

        #expect(result.loopMode == .blocked)
    }

    @Test("evaluate enters fullLoop on even temp target below 100") func evaluateFullLoopBelow100() throws {
        let profile = makeProfile()

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: 80,
            microBolusAllowed: true,
            iob: 0,
            b30IsActive: false,
            exerciseRatio: 1,
            overrideSmbIsOff: false
        )!

        #expect(result.loopMode == .fullLoop)
        #expect(result.smbEnabled)
    }

    @Test("evaluate enforces SMB on even target at or above 100") func evaluateEnforcedAtOrAbove100() throws {
        let profile = makeProfile()

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: 100,
            microBolusAllowed: true,
            iob: 0,
            b30IsActive: false,
            exerciseRatio: 1,
            overrideSmbIsOff: false
        )!

        #expect(result.loopMode == .enforced)
        #expect(result.smbEnabled)
    }

    @Test("evaluate detects even target in mmol/L units") func evaluateEvenTargetMmolL() throws {
        // 5.6 mmol/L → 56 (×10) → even
        let profile = makeProfile(targetUnits: .mmolL)

        let result = AutoISFsmb.evaluate(
            profile: profile,
            targetBG: Decimal(string: "5.6")!,
            microBolusAllowed: true,
            iob: 0,
            b30IsActive: false,
            exerciseRatio: 1,
            overrideSmbIsOff: false
        )!

        // 5.6 < 100 → fullLoop branch (mmol/L value compared against 100 mg/dL constant)
        #expect(result.loopMode == .fullLoop)
    }

    // MARK: - iobTHValues()

    @Test("iobTHValues computes effective and virtual ceilings") func iobTHValuesComputed() throws {
        // maxIob=10, iobThresholdPercent=0.5 → effective=5, virtual=6.5
        let profile = makeProfile(iobThresholdPercent: Decimal(string: "0.5")!)
        let values = AutoISFsmb.iobTHValues(profile: profile, exerciseRatio: 1)

        #expect(values.effective == 5)
        #expect(values.virtual == Decimal(string: "6.5"))
    }

    @Test("iobTHValues clamps effective ceiling to maxIob") func iobTHValuesClampedToMaxIob() throws {
        // iobThresholdPercent=1.5 would give 15 — clamped to maxIob=10
        let profile = makeProfile(iobThresholdPercent: Decimal(string: "1.5")!)
        let values = AutoISFsmb.iobTHValues(profile: profile, exerciseRatio: 1)

        #expect(values.effective == 10)
    }

    // MARK: - variableSMBRatio()

    @Test("variableSMBRatio returns fixed ratio when bgRange is zero") func varSMBFixedWhenRangeZero() throws {
        let profile = makeProfile(smbDeliveryRatio: Decimal(string: "0.5")!, smbDeliveryRatioBGrange: 0)

        let ratio = AutoISFsmb.variableSMBRatio(
            profile: profile,
            currentGlucose: 150,
            targetGlucose: 100,
            loopMode: .enforced
        )

        #expect(ratio == Decimal(string: "0.5"))
    }

    @Test("variableSMBRatio clamps to lower bound when BG <= target") func varSMBClampsLowAtTarget() throws {
        let profile = makeProfile(
            smbDeliveryRatioBGrange: 20,
            smbDeliveryRatioMin: Decimal(string: "0.4")!,
            smbDeliveryRatioMax: Decimal(string: "0.8")!
        )

        let ratio = AutoISFsmb.variableSMBRatio(
            profile: profile,
            currentGlucose: 100,
            targetGlucose: 100,
            loopMode: .enforced
        )

        #expect(ratio == Decimal(string: "0.4"))
    }

    @Test("variableSMBRatio clamps to upper bound past higherBG") func varSMBClampsHighAboveRange() throws {
        // higherBG = target+range = 100+20 = 120; bg=130 above → higherSMB=0.8
        let profile = makeProfile(
            smbDeliveryRatioBGrange: 20,
            smbDeliveryRatioMin: Decimal(string: "0.4")!,
            smbDeliveryRatioMax: Decimal(string: "0.8")!
        )

        let ratio = AutoISFsmb.variableSMBRatio(
            profile: profile,
            currentGlucose: 130,
            targetGlucose: 100,
            loopMode: .enforced
        )

        #expect(ratio == Decimal(string: "0.8"))
    }

    @Test("variableSMBRatio ramps linearly between target and higherBG") func varSMBLinearRamp() throws {
        // bg=110, target=100, range=20, [0.4, 0.8] → 0.4 + 0.4*(10/20) = 0.6
        let profile = makeProfile(
            smbDeliveryRatioBGrange: 20,
            smbDeliveryRatioMin: Decimal(string: "0.4")!,
            smbDeliveryRatioMax: Decimal(string: "0.8")!
        )

        let ratio = AutoISFsmb.variableSMBRatio(
            profile: profile,
            currentGlucose: 110,
            targetGlucose: 100,
            loopMode: .enforced
        )

        #expect(ratio == Decimal(string: "0.6"))
    }

    @Test("variableSMBRatio in fullLoop mode applies fixed-ratio floor") func varSMBFullLoopFloor() throws {
        // ramped value at bg=100, target=100, range=20 would be 0.4 — but fullLoop floors to fixed=0.5
        let profile = makeProfile(
            smbDeliveryRatio: Decimal(string: "0.5")!,
            smbDeliveryRatioBGrange: 20,
            smbDeliveryRatioMin: Decimal(string: "0.4")!,
            smbDeliveryRatioMax: Decimal(string: "0.8")!
        )

        let ratio = AutoISFsmb.variableSMBRatio(
            profile: profile,
            currentGlucose: 100,
            targetGlucose: 100,
            loopMode: .fullLoop
        )

        #expect(ratio == Decimal(string: "0.5"))
    }

    // MARK: - applyIobTHcap()

    @Test("applyIobTHcap is a no-op when autoISF is disabled") func iobTHcapNoOpDisabled() throws {
        let profile = makeProfile(autoisf: false)

        let smbResult = AutoISFsmbResult(
            loopMode: .enforced,
            iobTHEffective: 5,
            iobTHVirtual: Decimal(string: "6.5")!,
            reason: ""
        )
        let out = AutoISFsmb.applyIobTHcap(
            profile: profile,
            currentIob: 5,
            microBolus: 10,
            smbResult: smbResult,
            reason: "x"
        )

        #expect(out.microBolus == 10)
        #expect(out.reasonTail == "")
    }

    @Test("applyIobTHcap is a no-op when iobThresholdPercent is 1") func iobTHcapNoOpAtFullPercent() throws {
        let profile = makeProfile() // default iobThresholdPercent = 1
        let smbResult = AutoISFsmbResult(
            loopMode: .enforced,
            iobTHEffective: 10,
            iobTHVirtual: 13,
            reason: ""
        )
        let out = AutoISFsmb.applyIobTHcap(
            profile: profile,
            currentIob: 5,
            microBolus: 10,
            smbResult: smbResult,
            reason: "x"
        )

        #expect(out.microBolus == 10)
        #expect(out.reasonTail == "")
    }

    @Test("applyIobTHcap reduces microBolus when virtual ceiling would be exceeded") func iobTHcapReducesBolus() throws {
        // virtual=6.5, currentIob=5 → headroom 1.5; microBolus=2 exceeds → cap to 1.5
        let profile = makeProfile(iobThresholdPercent: Decimal(string: "0.5")!)
        let smbResult = AutoISFsmbResult(
            loopMode: .enforced,
            iobTHEffective: 5,
            iobTHVirtual: Decimal(string: "6.5")!,
            reason: "autoISF-SMB enabled:, even Target, eff.iobTH:, 5"
        )

        let out = AutoISFsmb.applyIobTHcap(
            profile: profile,
            currentIob: 5,
            microBolus: 2,
            smbResult: smbResult,
            reason: "Microbolusing 2u"
        )

        #expect(out.microBolus == Decimal(string: "1.5"))
        #expect(out.reasonTail == ", capped by autoISF iobTH")
    }

    @Test("applyIobTHcap leaves bolus unchanged when within virtual ceiling") func iobTHcapWithinHeadroom() throws {
        // virtual=6.5, currentIob=5, headroom=1.5 ; microBolus=1 (<1.5) → unchanged
        let profile = makeProfile(iobThresholdPercent: Decimal(string: "0.5")!)
        let smbResult = AutoISFsmbResult(
            loopMode: .enforced,
            iobTHEffective: 5,
            iobTHVirtual: Decimal(string: "6.5")!,
            reason: ""
        )

        let out = AutoISFsmb.applyIobTHcap(
            profile: profile,
            currentIob: 5,
            microBolus: 1,
            smbResult: smbResult,
            reason: "Microbolusing 1u"
        )

        #expect(out.microBolus == 1)
        #expect(out.reasonTail == "")
    }

    // MARK: - applySmbMaxRange()

    @Test("applySmbMaxRange returns input unchanged when autoISF is disabled") func smbMaxRangeAutoISFOff() throws {
        let profile = makeProfile(autoisf: false, smbMaxRangeExtension: 2)
        let out = AutoISFsmb.applySmbMaxRange(profile: profile, maxBolus: 5)
        #expect(out == 5)
    }

    @Test("applySmbMaxRange multiplies maxBolus by extension when autoISF is enabled") func smbMaxRangeMultiplies() throws {
        let profile = makeProfile(smbMaxRangeExtension: Decimal(string: "1.5")!)
        let out = AutoISFsmb.applySmbMaxRange(profile: profile, maxBolus: 4)
        #expect(out == 6)
    }
}
