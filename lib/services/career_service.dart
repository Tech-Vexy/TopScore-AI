// import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/grade_model.dart';

class CareerService {
  // Mock Data conforming to Kenyan High School grading
  List<GradeModel> getMockGrades() {
    return [
      GradeModel(
        subject: 'Mathematics',
        percentage: 85,
        grade: 'A',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'English',
        percentage: 78,
        grade: 'A-',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'Kiswahili',
        percentage: 72,
        grade: 'B+',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'Physics',
        percentage: 88,
        grade: 'A',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'Chemistry',
        percentage: 65,
        grade: 'B',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'Biology',
        percentage: 82,
        grade: 'A-',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'History',
        percentage: 55,
        grade: 'C',
        term: 'Term 3',
      ),
      GradeModel(
        subject: 'Geography',
        percentage: 60,
        grade: 'B-',
        term: 'Term 3',
      ),
    ];
  }

  Future<String> analyzePerformance(List<GradeModel> grades) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null) return "Error: API Key not found.";

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

      final gradesString = grades
          .map((g) => "${g.subject}: ${g.percentage}% (${g.grade})")
          .join(", ");

      final prompt =
          """
      Analyze these Kenyan High School (KCSE) student grades: $gradesString.
      
      Provide a markdown response with:
      1. **Strengths**: Identify top 3 strong subjects.
      2. **Weaknesses**: Identify subjects needing improvement.
      3. **Career Suggestions**: Recommend 3 suitable career paths based on the strengths (e.g., Engineering, Medicine, Law).
      4. **Study Tip**: One actionable tip to improve the weakest subject.
      
      Keep it encouraging and concise.
      """;

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? "Unable to analyze grades.";
    } catch (e) {
      return "Error analyzing performance: $e";
    }
  }

  Future<String> generateRoadmap(String careerInterest) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null) return "Error: API Key not found.";

      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

      final prompt =
          """
      Create a step-by-step roadmap for a Kenyan student who wants to become a **$careerInterest**.
      
      Include:
      1. **High School**: Required KCSE subjects and minimum grades (Cluster Subjects).
      2. **University**: Top 3 Kenyan universities offering this course.
      3. **Duration**: How many years the degree/diploma takes.
      4. **Professional Body**: Relevant registration body in Kenya (e.g., EBK, KMPDC, LSK).
      
      Format as a clear markdown list.
      """;

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? "Unable to generate roadmap.";
    } catch (e) {
      return "Error generating roadmap: $e";
    }
  }
}
