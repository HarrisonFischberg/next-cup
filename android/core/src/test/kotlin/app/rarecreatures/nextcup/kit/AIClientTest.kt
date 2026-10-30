package app.rarecreatures.nextcup.kit

import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class StubTransport(responses: List<Result<HTTPResult>>) : Transport {
    private val queue = responses.toMutableList()
    val requests = mutableListOf<HttpRequest>()
    override suspend fun send(request: HttpRequest): HTTPResult {
        requests += request
        return queue.removeAt(0).getOrThrow()
    }
}

class AIClientTest {
    private val schema = JSONSchema.Obj(mapOf("field" to JSONSchema.Str(listOf("grind", "temperature")), "delta" to JSONSchema.Int))
    private val answer = """{"field":"grind","delta":-2}"""
    private fun payload(image: ByteArray? = null) = AIRequestPayload("s", "u", "suggest", schema, image)
    private fun client(stub: StubTransport, key: String? = "sk-test", disclosed: Set<AIProviderKind> = AIProviderKind.entries.toSet()) =
        AIClient(stub, { key }, { it in disclosed }, sleep = {})
    private fun ok(body: String) = Result.success(HTTPResult(200, body.toByteArray()))
    private fun status(code: Int) = Result.success(HTTPResult(code, ByteArray(0)))
    private fun anthropicBody(text: String = answer) =
        """{"content":[{"type":"thinking","thinking":""},{"type":"text","text":"${text.replace("\"", "\\\"")}"}]}"""
    private fun openAIBody(text: String) = """{"output":[{"type":"message","content":[{"type":"output_text","text":"${text.replace("\"", "\\\"")}"}]}]}"""

    private suspend fun expectError(expected: AIError, block: suspend () -> Unit) {
        try {
            block()
            fail("expected $expected")
        } catch (e: AIError) {
            assertEquals(expected, e)
        }
    }

    @Test fun noKeyMeansNoCall() = runTest {
        val stub = StubTransport(emptyList())
        expectError(AIError.NoKey) { client(stub, key = null).send(payload(), AIProviderKind.ANTHROPIC, "m") }
        expectError(AIError.NoKey) { client(stub, key = "").send(payload(), AIProviderKind.OPENAI, "m") }
        assertTrue(stub.requests.isEmpty())
    }

    @Test fun noDisclosureMeansNoCall() = runTest {
        val stub = StubTransport(emptyList())
        expectError(AIError.DisclosureNotAccepted) { client(stub, disclosed = emptySet()).send(payload(), AIProviderKind.ANTHROPIC, "m") }
        assertTrue(stub.requests.isEmpty())
    }

    @Test fun disclosureForOneProviderDoesNotUnlockAnother() = runTest {
        val stub = StubTransport(emptyList())
        expectError(AIError.DisclosureNotAccepted) { client(stub, disclosed = setOf(AIProviderKind.ANTHROPIC)).send(payload(), AIProviderKind.OPENAI, "m") }
        assertTrue(stub.requests.isEmpty())
    }

    @Test fun anthropicRequestAndResult() = runTest {
        val stub = StubTransport(listOf(ok(anthropicBody())))
        val image = byteArrayOf(1, 2, 3)
        val result = client(stub).send(payload(image), AIProviderKind.ANTHROPIC, "model-a")
        assertEquals("""{"delta":-2,"field":"grind"}""", result.json)
        val request = stub.requests.first()
        assertEquals("https://api.anthropic.com/v1/messages", request.url)
        assertEquals("sk-test", request.headers["x-api-key"])
        assertTrue(request.headers["anthropic-version"] != null)
        assertEquals(120, request.timeoutS)
        val body = request.body!!
        assertTrue(body.contains("\"model\":\"model-a\""))
        assertTrue(body.contains(java.util.Base64.getEncoder().encodeToString(image)))
        assertTrue(body.contains("\"json_schema\""))
        assertFalse("current models refuse a forced tool", body.contains("\"tool_choice\""))
        assertFalse("no effort unless one is chosen", body.contains("\"effort\""))
    }

    @Test fun effortIsSentWhenChosen() = runTest {
        val stub = StubTransport(listOf(ok(anthropicBody()), ok(openAIBody(answer))))
        client(stub).send(payload(), AIProviderKind.ANTHROPIC, "m", "low")
        client(stub).send(payload(), AIProviderKind.OPENAI, "m", "high")
        assertTrue(stub.requests[0].body!!.contains(""""output_config":{"effort":"low""""))
        assertTrue(stub.requests[1].body!!.contains(""""reasoning":{"effort":"high"}"""))
    }

    @Test fun modelsListChecksTheKey() = runTest {
        val stub = StubTransport(
            listOf(
                ok("""{"data":[{"id":"claude-a"},{"id":"claude-b"}]}"""),
                ok("""{"data":[{"id":"gpt-5"},{"id":"tts-1"},{"id":"o4-mini"},{"id":"gpt-4o-audio"}]}"""),
                status(401),
            ),
        )
        assertEquals(listOf("claude-a", "claude-b"), client(stub).models(AIProviderKind.ANTHROPIC))
        assertEquals(listOf("o4-mini", "gpt-5"), client(stub).models(AIProviderKind.OPENAI))
        expectError(AIError.KeyRejected) { client(stub).models(AIProviderKind.ANTHROPIC) }
    }

    @Test fun openAIRequestAndResult() = runTest {
        val stub = StubTransport(listOf(ok(openAIBody(answer))))
        assertEquals("""{"delta":-2,"field":"grind"}""", client(stub).send(payload(), AIProviderKind.OPENAI, "model-o").json)
        val request = stub.requests.first()
        assertEquals("https://api.openai.com/v1/responses", request.url)
        assertEquals("Bearer sk-test", request.headers["Authorization"])
        assertTrue(request.body!!.contains("\"json_schema\""))
    }

    @Test fun rejectedKeyStopsAtOnce() = runTest {
        val stub = StubTransport(listOf(status(401), status(200)))
        expectError(AIError.KeyRejected) { client(stub).send(payload(), AIProviderKind.ANTHROPIC, "m") }
        assertEquals(1, stub.requests.size)
    }

    @Test fun retriesStopAtThree() = runTest {
        val stub = StubTransport(listOf(status(429), status(529), status(500), ok(anthropicBody())))
        expectError(AIError.Unavailable(500)) { client(stub).send(payload(), AIProviderKind.ANTHROPIC, "m") }
        assertEquals(3, stub.requests.size)
    }

    @Test fun retryThenSucceed() = runTest {
        val stub = StubTransport(listOf(status(429), ok(anthropicBody())))
        client(stub).send(payload(), AIProviderKind.ANTHROPIC, "m")
        assertEquals(2, stub.requests.size)
    }

    @Test fun backoffDoubles() = runTest {
        val waits = mutableListOf<Long>()
        val stub = StubTransport(listOf(status(500), status(500), ok(anthropicBody())))
        AIClient(stub, { "k" }, { true }, backoffMs = 1000, sleep = { waits += it }).send(payload(), AIProviderKind.ANTHROPIC, "m")
        assertEquals(listOf(1000L, 2000L), waits)
    }

    @Test fun invalidOutputIsDiscarded() = runTest {
        val bodies = listOf(
            "not json", """{"content":[]}""",
            """{"content":[{"type":"text","text":"{\"field\":\"grind\"}"}]}""",
            """{"content":[{"type":"text","text":"{\"field\":\"water\",\"delta\":1}"}]}""",
            """{"content":[{"type":"text","text":"{\"field\":\"grind\",\"delta\":1.5}"}]}""",
            """{"content":[{"type":"text","text":"{\"field\":\"grind\",\"delta\":1,\"extra\":true}"}]}""",
            """{"content":[{"type":"text","text":"sure, grind finer"}]}""",
        )
        for (body in bodies) {
            val stub = StubTransport(listOf(ok(body), ok(anthropicBody())))
            expectError(AIError.InvalidResponse) { client(stub).send(payload(), AIProviderKind.ANTHROPIC, "m") }
            assertEquals(body, 1, stub.requests.size)
        }
    }

    @Test fun openAIOutputThatIsNotJSONIsDiscarded() = runTest {
        expectError(AIError.InvalidResponse) { client(StubTransport(listOf(ok(openAIBody("sure, lower the grind"))))).send(payload(), AIProviderKind.OPENAI, "m") }
    }

    @Test fun timeoutsAreRetriedThenGiveUp() = runTest {
        val stub = StubTransport(List(3) { Result.failure(java.net.SocketTimeoutException()) })
        expectError(AIError.Unavailable(null)) { client(stub).send(payload(), AIProviderKind.ANTHROPIC, "m") }
        assertEquals(AIClient.MAX_ATTEMPTS, stub.requests.size)
    }

    @Test fun cancellingStopsWithoutRetrying() = runTest {
        val stub = StubTransport(listOf(Result.failure(kotlinx.coroutines.CancellationException()), ok(anthropicBody())))
        expectError(AIError.Cancelled) { client(stub).send(payload(), AIProviderKind.ANTHROPIC, "m") }
        assertEquals(1, stub.requests.size)
    }

    @Test fun anthropicAnswerOutsideTheSchemaIsDiscarded() = runTest {
        expectError(AIError.InvalidResponse) { client(StubTransport(listOf(ok(anthropicBody("""{"field":"grind"}"""))))).send(payload(), AIProviderKind.ANTHROPIC, "m") }
    }

    @Test fun offlineIsNotRetried() = runTest {
        val stub = StubTransport(listOf(Result.failure(OfflineException()), ok(anthropicBody())))
        expectError(AIError.Offline) { client(stub).send(payload(), AIProviderKind.ANTHROPIC, "m") }
        assertEquals(1, stub.requests.size)
    }

    @Test fun schemaDistinguishesBooleansFromNumbers() {
        val value = Json.parseToJsonElement("""{"a":true,"b":1}""")
        assertTrue(JSONSchema.Obj(mapOf("a" to JSONSchema.Bool, "b" to JSONSchema.Int)).validates(value))
        assertFalse(JSONSchema.Obj(mapOf("a" to JSONSchema.Int, "b" to JSONSchema.Bool)).validates(value))
    }

    @Test fun payloadCodingOmitsTheImage() {
        val original = payload(byteArrayOf(9))
        val decoded = Json.decodeFromString(AIRequestPayload.serializer(), Json.encodeToString(AIRequestPayload.serializer(), original))
        assertNull(decoded.imageJPEG)
        assertEquals(original.schema, decoded.schema)
    }
}

class PaperImportTest {
    private fun lines(texts: List<String>, confidence: Double = 0.95) = texts.map { PaperLine(it, confidence) }

    @Test fun labelledLinesFillTheDraft() {
        val d = PaperImport.parse(
            lines(listOf("Method: Hario V60", "Beans: Finca Alta", "Dose 18 g", "Water: 288g", "Temp 94 C", "Time: 2:45", "Grind - 24 clicks", "Rating 4.5/5", "Notes: panela, bright")),
        )
        assertEquals("Hario V60", d.method)
        assertEquals("Finca Alta", d.bean)
        assertEquals(18.0, d.doseG)
        assertEquals(288.0, d.waterG)
        assertEquals(94.0, d.tempC)
        assertEquals(165, d.totalTimeS)
        assertEquals("24 clicks", d.grind)
        assertEquals(90, d.ratingTenths)
        assertEquals("panela, bright", d.notes)
        assertEquals(0, d.needsCheckCount)
    }

    @Test fun unitsAndSpellingsConvertToCanonical() {
        val d = PaperImport.parse(lines(listOf("Dose: 0.5 oz", "Water 10,5 oz", "Temperature 200 F", "Time 2 min 30", "Stars ★★★★")))
        assertEquals(14.17, d.doseG!!, 0.01)
        assertEquals(297.67, d.waterG!!, 0.01)
        assertEquals(93.33, d.tempC!!, 0.01)
        assertEquals(150, d.totalTimeS)
        assertEquals(80, d.ratingTenths)
    }

    @Test fun timeAndRatingForms() {
        fun seconds(t: String) = PaperImport.parse(lines(listOf("Time: $t"))).totalTimeS
        assertEquals(150, seconds("150"))
        assertEquals(150, seconds("150 s"))
        assertEquals(150, seconds("2.5 min"))
        assertNull(seconds("0"))
        assertNull(seconds("9999"))
        fun grade(t: String) = PaperImport.parse(lines(listOf("Rating: $t"))).ratingTenths
        assertEquals(80, grade("8/10"))
        assertEquals(74, grade("7.4/10"))
        assertEquals(80, grade("4"))
        assertEquals(90, grade("9"))
        assertNull(grade("11"))
    }

    @Test fun coffeeIsADoseWhenNumericAndABeanWhenNot() {
        val dose = PaperImport.parse(lines(listOf("Coffee: 20 g")))
        assertEquals(20.0, dose.doseG)
        assertTrue(dose.bean.isEmpty())
        val bean = PaperImport.parse(lines(listOf("Coffee: Ethiopia Guji")))
        assertEquals("Ethiopia Guji", bean.bean)
        assertNull(bean.doseG)
    }

    @Test fun implausibleValuesAreNotMapped() {
        val d = PaperImport.parse(lines(listOf("Dose: 4000 g", "Temp: 300 C", "Water temp 94", "Time: soon")))
        assertNull(d.doseG)
        assertNull(d.tempC)
        assertNull(d.waterG)
        assertNull(d.totalTimeS)
        assertTrue(d.notes.contains("Dose: 4000 g"))
        assertTrue(d.notes.contains("Water temp 94"))
    }

    @Test fun unlabelledLinesBecomeNotesAndLabelledNotesComeFirst() {
        val d = PaperImport.parse(lines(listOf("Notes: sweet", "second cup was flat", "Dose 15g")))
        assertEquals("sweet\nsecond cup was flat", d.notes)
        assertEquals(15.0, d.doseG)
    }

    @Test fun lowConfidenceFieldsAreFlagged() {
        val d = PaperImport.parse(listOf(PaperLine("Dose 18 g", 0.95), PaperLine("Water 3OO g", 0.9), PaperLine("Time: 2:45", 0.4), PaperLine("Grind 24", 0.59)))
        assertTrue(d.needsCheck(PaperField.TIME))
        assertTrue(d.needsCheck(PaperField.GRIND))
        assertFalse(d.needsCheck(PaperField.DOSE))
        assertNull(d.waterG)
        assertEquals("Water 3OO g", d.notes)
        assertFalse(d.needsCheck(PaperField.NOTES))
        assertFalse(d.needsCheck(PaperField.METHOD))
    }

    @Test fun aNotesLineReadUnsurelyIsFlagged() {
        val d = PaperImport.parse(listOf(PaperLine("kinda fruity?", 0.3)))
        assertTrue(d.needsCheck(PaperField.NOTES))
        assertEquals("kinda fruity?", d.notes)
    }

    @Test fun blankPageIsEmpty() {
        assertTrue(PaperImport.parse(emptyList()).isEmpty)
        assertTrue(PaperImport.parse(lines(listOf("  ", ""))).isEmpty)
    }

    private val answer = """{"method":"V60","bean":"Finca Alta","doseGrams":18,"waterGrams":288,"temperatureCelsius":94,""" +
        """"timeSeconds":165,"grind":"24","ratingOutOfFive":4.5,"notes":"panela","uncertain":"grind, time"}"""

    @Test fun aiAnswerMapsThroughTheSameRulesWithItsOwnDoubts() {
        val d = PaperImport.draftFromAI(answer)!!
        assertEquals("V60", d.method)
        assertEquals(18.0, d.doseG)
        assertEquals(94.0, d.tempC)
        assertEquals(165, d.totalTimeS)
        assertEquals(90, d.ratingTenths)
        assertTrue(d.needsCheck(PaperField.GRIND))
        assertTrue(d.needsCheck(PaperField.TIME))
        assertFalse(d.needsCheck(PaperField.DOSE))
    }

    @Test fun aiZerosAreBlankAndAbsurdValuesDropped() {
        val d = PaperImport.draftFromAI(answer.replace(""""doseGrams":18""", """"doseGrams":0""").replace(""""temperatureCelsius":94""", """"temperatureCelsius":900"""))!!
        assertNull(d.doseG)
        assertNull(d.tempC)
        assertEquals(288.0, d.waterG)
    }

    @Test fun aiAnswersOutsideTheSchemaAreDiscarded() {
        for (bad in listOf("""{"method":"V60"}""", "a page of coffee", answer.replace("165", "\"soon\""))) assertNull(PaperImport.draftFromAI(bad))
    }

    @Test fun payloadCarriesThePhotoAndSchema() {
        val p = PaperImport.payload(byteArrayOf(1, 2))
        assertTrue(p.imageJPEG!!.contentEquals(byteArrayOf(1, 2)))
        assertEquals(PaperImport.schema, p.schema)
    }
}
